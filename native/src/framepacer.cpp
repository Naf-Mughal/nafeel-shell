#include "framepacer.h"

#include <QAnimationDriver>
#include <QGuiApplication>
#include <QScreen>
#include <QtQuick/private/qsgrenderloop_p.h>

#include <cmath>
#include <ctime>
#include <functional>

#include <QDir>
#include <QMutex>
#include <QThread>
#include <QWaitCondition>
#include <fcntl.h>
#include <unistd.h>
#include <xf86drm.h>

// Uses Qt's private render-loop API (the driver it installed): rebuilt
// against each Qt minor version like the rest of the module (build.sh).

namespace {

qint64 monotonicUs() {
    timespec ts{};
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return qint64(ts.tv_sec) * 1000000 + ts.tv_nsec / 1000;
}

} // namespace

// Waits for the display's vblanks (the kernel's, DRM_IOCTL_WAIT_VBLANK: no
// DRM master needed) while animations run, and hands each one's time to
// the driver on the GUI thread. Asleep otherwise.
class VblankThread : public QThread {
public:
    std::function<void(qint64 us, quint32 seq)> onVblank;

    ~VblankThread() override {
        {
            QMutexLocker lock(&m_mutex);
            m_quit = true;
            m_cond.wakeAll();
        }
        wait();
        if (m_fd >= 0)
            ::close(m_fd);
    }

    bool open() {
        // The card driving the displays (the one with a connected connector).
        QDir dri(QStringLiteral("/dev/dri"));
        for (const QString &name : dri.entryList({QStringLiteral("card*")}, QDir::System)) {
            const int fd = ::open(dri.filePath(name).toLocal8Bit().constData(), O_RDWR | O_CLOEXEC);
            if (fd < 0)
                continue;
            drmVBlank v{};
            v.request.type = DRM_VBLANK_RELATIVE;
            v.request.sequence = 0;
            if (drmWaitVBlank(fd, &v) == 0) {
                m_fd = fd;
                return true;
            }
            ::close(fd);
        }
        return false;
    }

    void want(bool on) {
        QMutexLocker lock(&m_mutex);
        m_wanted = on;
        if (on)
            m_cond.wakeAll();
    }

    bool failed() const { return m_failed.loadRelaxed(); }

protected:
    void run() override {
        while (true) {
            {
                QMutexLocker lock(&m_mutex);
                while (!m_wanted && !m_quit)
                    m_cond.wait(&m_mutex);
                if (m_quit)
                    return;
            }
            drmVBlank v{};
            v.request.type = DRM_VBLANK_RELATIVE;
            v.request.sequence = 1;
            if (drmWaitVBlank(m_fd, &v) != 0) {
                // No vblanks (the display off: locked, asleep): the driver's
                // timer carries on; try again shortly, so it locks back on
                // once the screen is back.
                m_failed.storeRelaxed(true);
                QThread::msleep(250);
                continue;
            }
            m_failed.storeRelaxed(false);
            if (onVblank)
                onVblank(qint64(v.reply.tval_sec) * 1000000 + v.reply.tval_usec, v.reply.sequence);
        }
    }

private:
    int m_fd = -1;
    QMutex m_mutex;
    QWaitCondition m_cond;
    bool m_wanted = false;
    bool m_quit = false;
    QAtomicInteger<bool> m_failed{false};
};

class FramePacerDriver : public QAnimationDriver {
public:
    FramePacerDriver() {
        m_origin = monotonicUs();
        m_fallback.setTimerType(Qt::PreciseTimer);
        m_fallback.setSingleShot(true);
        QObject::connect(&m_fallback, &QTimer::timeout, this, [this]() {
            // No vblank came (no DRM device, or it stopped): keep going on
            // the clock.
            if (isRunning())
                step(monotonicUs(), 0);
        });
        if (m_vblank.open()) {
            m_vblank.onVblank = [this](qint64 us, quint32 seq) {
                m_latest.storeRelaxed(seq);
                QMetaObject::invokeMethod(this, [this, us, seq]() { step(us, seq); }, Qt::QueuedConnection);
            };
            m_vblank.start(QThread::TimeCriticalPriority);
            m_useVblank = true;
        }
    }

    ~FramePacerDriver() override { m_vblank.onVblank = nullptr; }

    // Time since this driver started, as Qt expects (it adds its own offset):
    // an absolute time made the first step from rest jump straight to the
    // end, so opens showed no animation.
    qint64 elapsed() const override { return isRunning() ? m_time : 0; }

protected:
    void start() override {
        m_origin = monotonicUs();
        m_time = 0;
        QAnimationDriver::start();
        if (m_useVblank && !m_vblank.failed())
            m_vblank.want(true);
        armFallback();
    }

    void stop() override {
        m_vblank.want(false);
        m_fallback.stop();
        QAnimationDriver::stop();
    }

private:
    void armFallback() {
        // Two refreshes without a vblank: the clock takes over.
        m_fallback.start(m_useVblank && !m_vblank.failed() ? 40 : 16);
    }

    void step(qint64 us, quint32 seq) {
        if (!isRunning())
            return;
        // Behind (the GUI thread was busy): only the newest vblank counts.
        if (seq && seq != quint32(m_latest.loadRelaxed()))
            return;
        // The frame shown at this vblank's successor: animations at the
        // vblank's own time, so every step is exactly one refresh.
        const qint64 t = (us - m_origin) / 1000;
        if (t <= m_time && seq)
            return;
        m_time = std::max(t, m_time);
        advance();
        armFallback();
    }

    VblankThread m_vblank;
    bool m_useVblank = false;
    QAtomicInteger<quint32> m_latest{0};
    QTimer m_fallback;
    qint64 m_origin = 0;
    qint64 m_time = 0;
};

FramePacer::FramePacer(QObject *parent) : QObject(parent) {}

FramePacer::~FramePacer() {
    if (m_driver) {
        m_driver->uninstall();
        delete m_driver;
    }
}

void FramePacer::attach(QQuickWindow *window) {
    if (!window)
        return;
    if (qEnvironmentVariable("NAFEEL_FRAME_PACER") == QLatin1String("0"))
        return;
    if (!m_driver) {
        QSGRenderLoop *loop = QSGRenderLoop::instance();
        QAnimationDriver *qtDriver = loop ? loop->animationDriver() : nullptr;
        if (qtDriver)
            qtDriver->uninstall();
        m_driver = new FramePacerDriver();
        m_driver->install();
        emit activeChanged();
    }
    Q_UNUSED(window);
}
