#include "framepacer.h"

#include <QAnimationDriver>
#include <QGuiApplication>
#include <QScreen>
#include <QtQuick/private/qsgrenderloop_p.h>

#include <cmath>
#include <ctime>
#include <functional>

#include <QDir>
#include <QEvent>
#include <QMutex>
#include <QThread>
#include <QWaitCondition>
#include <fcntl.h>
#include <unistd.h>
#include <xf86drm.h>
#include <csignal>
#include <execinfo.h>
#include <pthread.h>

#include <QFile>
#include <qpa/qplatformnativeinterface.h>
#include <wayland-client.h>
#include "presentation-time-client-protocol.h"

// Uses Qt's private render-loop API (the driver it installed): rebuilt
// against each Qt minor version like the rest of the module (build.sh).

namespace {

qint64 monotonicUs() {
    timespec ts{};
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return qint64(ts.tv_sec) * 1000000 + ts.tv_nsec / 1000;
}

} // namespace

// NAFEEL_STALL_TRACE=<file>: for measuring. When a vblank's tick hasn't
// reached the GUI thread ~10 ms on, its stack is written there (a signal
// to the GUI thread; the handler isn't async-signal-safe, it's a probe).
namespace stalltrace {
int fd = -1;
pthread_t gui;
void handler(int) {
    if (fd < 0)
        return;
    void *bt[48];
    const int n = backtrace(bt, 48);
    timespec ts{};
    clock_gettime(CLOCK_MONOTONIC, &ts);
    char head[64];
    const int len = snprintf(head, sizeof head, "=== %ld.%06ld\n", long(ts.tv_sec), ts.tv_nsec / 1000);
    (void)!::write(fd, head, len);
    backtrace_symbols_fd(bt, n, fd);
}
} // namespace stalltrace

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
    QAtomicInteger<quint32> handled{0};

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
            if (stalltrace::fd >= 0) {
                // The previous tick still unhandled after ~10 ms: trace.
                QThread::usleep(6000);
                if (handled.loadRelaxed() + 1 < v.reply.sequence + 1 && handled.loadRelaxed() != v.reply.sequence)
                    pthread_kill(stalltrace::gui, SIGUSR2);
            }
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

// NAFEEL_PRESENT_LOG=<file>: for measuring. Asks the compositor, at each
// paced step, when the window's next frame reached the screen
// (wp_presentation): one line per frame, "P <ns> <msc>" when shown at
// vblank <msc>, "D <ns>" when it was replaced before it was ever shown.
class PresentLog {
public:
    bool open(const QString &path) {
        auto *app = qGuiApp->nativeInterface<QNativeInterface::QWaylandApplication>();
        if (!app)
            return false;
        m_display = app->display();
        m_queue = wl_display_create_queue(m_display);
        auto *wrapped = static_cast<wl_display *>(wl_proxy_create_wrapper(m_display));
        wl_proxy_set_queue(reinterpret_cast<wl_proxy *>(wrapped), m_queue);
        wl_registry *registry = wl_display_get_registry(wrapped);
        wl_proxy_wrapper_destroy(wrapped);
        static const wl_registry_listener listener = {
            [](void *data, wl_registry *r, uint32_t name, const char *iface, uint32_t) {
                if (qstrcmp(iface, wp_presentation_interface.name) == 0)
                    static_cast<PresentLog *>(data)->m_presentation = static_cast<wp_presentation *>(wl_registry_bind(r, name, &wp_presentation_interface, 1));
            },
            [](void *, wl_registry *, uint32_t) {},
        };
        wl_registry_add_listener(registry, &listener, this);
        wl_display_roundtrip_queue(m_display, m_queue);
        m_file.setFileName(path);
        return m_presentation && m_file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text);
    }

    void watch(QQuickWindow *window, const std::function<qint64()> &animTime) {
        if (m_window)
            return;
        m_window = window;
        // At sync (render thread, GUI blocked): the frame's animation time;
        // a sync over 3 ms logged as "S <ns> <us>" (where opens lose frames).
        QObject::connect(window, &QQuickWindow::beforeSynchronizing, window, [this]() {
            m_syncStart.storeRelaxed(nowNs());
        }, Qt::DirectConnection);
        QObject::connect(window, &QQuickWindow::afterSynchronizing, window, [this, animTime]() {
            m_frameTime.storeRelaxed(animTime());
            const qint64 t = nowNs(), d = t - m_syncStart.loadRelaxed();
            if (d > 3000000)
                write(QStringLiteral("S %1 %2\n").arg(t).arg(d / 1000));
        }, Qt::DirectConnection);
        // Just before this frame's swap: feedback for exactly this commit;
        // a render over 6 ms logged as "R <ns> <us>".
        QObject::connect(window, &QQuickWindow::beforeRendering, window, [this]() {
            m_renderStart.storeRelaxed(nowNs());
        }, Qt::DirectConnection);
        QObject::connect(window, &QQuickWindow::afterRendering, window, [this]() {
            const qint64 t = nowNs(), d = t - m_renderStart.loadRelaxed();
            if (d > 6000000)
                write(QStringLiteral("R %1 %2\n").arg(t).arg(d / 1000));
            requestFeedback(m_frameTime.loadRelaxed());
        }, Qt::DirectConnection);
    }

    void requestFeedback(qint64 tag) {
        auto *surface = static_cast<wl_surface *>(QGuiApplication::platformNativeInterface()->nativeResourceForWindow("surface", m_window));
        if (!surface || !m_presentation)
            return;
        struct wp_presentation_feedback *fb = wp_presentation_feedback(m_presentation, surface);
        auto *ctx = new std::pair<PresentLog *, qint64>(this, tag);
        wp_presentation_feedback_add_listener(fb, &frameListener, ctx);
    }

    static const wp_presentation_feedback_listener frameListener;
    QAtomicInteger<qint64> m_frameTime{0};
    QAtomicInteger<qint64> m_syncStart{0};
    QAtomicInteger<qint64> m_renderStart{0};
    static qint64 nowNs() {
        timespec ts{};
        clock_gettime(CLOCK_MONOTONIC, &ts);
        return qint64(ts.tv_sec) * 1000000000LL + ts.tv_nsec;
    }

    void step(quint32 seq, qint64 vblankUs) {
        if (!m_presentation || !m_window)
            return;
        timespec now{};
        clock_gettime(CLOCK_MONOTONIC, &now);
        const qint64 nowUs = qint64(now.tv_sec) * 1000000 + now.tv_nsec / 1000;
        write(QStringLiteral("T %1 %2 %3\n").arg(nowUs * 1000).arg(seq).arg(vblankUs ? nowUs - vblankUs : -1));
        wl_display_dispatch_queue_pending(m_display, m_queue);
    }

    void write(const QString &line) {
        QMutexLocker lock(&m_writeLock);
        m_file.write(line.toUtf8());
        m_file.flush();
    }

private:
    wl_display *m_display = nullptr;
    wl_event_queue *m_queue = nullptr;
    wp_presentation *m_presentation = nullptr;
    QPointer<QQuickWindow> m_window;
    QFile m_file;
    QMutex m_writeLock;
};

const wp_presentation_feedback_listener PresentLog::frameListener = {
    [](void *, struct wp_presentation_feedback *, wl_output *) {},
    [](void *data, struct wp_presentation_feedback *fb, uint32_t hi, uint32_t lo, uint32_t ns, uint32_t, uint32_t mhi, uint32_t mlo, uint32_t) {
        auto *ctx = static_cast<std::pair<PresentLog *, qint64> *>(data);
        const qint64 t = ((qint64(hi) << 32) | lo) * 1000000000LL + ns;
        const quint64 msc = (quint64(mhi) << 32) | mlo;
        ctx->first->write(QStringLiteral("F %1 %2 %3\n").arg(t).arg(msc).arg(ctx->second));
        delete ctx;
        wp_presentation_feedback_destroy(fb);
    },
    [](void *data, struct wp_presentation_feedback *fb) {
        auto *ctx = static_cast<std::pair<PresentLog *, qint64> *>(data);
        timespec ts{};
        clock_gettime(CLOCK_MONOTONIC, &ts);
        ctx->first->write(QStringLiteral("X %1 %2\n").arg(qint64(ts.tv_sec) * 1000000000LL + ts.tv_nsec).arg(ctx->second));
        delete ctx;
        wp_presentation_feedback_destroy(fb);
    },
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
        if (const QByteArray p = qgetenv("NAFEEL_STALL_TRACE"); !p.isEmpty()) {
            stalltrace::fd = ::open(p.constData(), O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0644);
            stalltrace::gui = pthread_self();
            std::signal(SIGUSR2, stalltrace::handler);
        }
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

    // While animations run, a frame starts only at a vblank: the first update
    // request after each tick passes; any more before the next tick (a layer's
    // texture asking again from the render thread, a queued update) wait for
    // it. Delivered between refreshes they drew a frame out of step, and the
    // next paced one landed a refresh late.
    void watch(QQuickWindow *window, bool strict = false) {
        for (const auto &w : std::as_const(m_windows))
            if (w.window == window)
                return;
        m_windows.append({window, true, false, strict, false, QSize()});
        window->installEventFilter(this);
        if (!m_logChecked) {
            m_logChecked = true;
            const QString path = qEnvironmentVariable("NAFEEL_PRESENT_LOG");
            if (!path.isEmpty() && m_log.open(path))
                m_logging = true;
        }
        if (m_logging && !strict)
            m_log.watch(window, [this]() { return (m_origin / 1000) + m_time; });
    }

    void mark(const QString &what) {
        if (!m_logging)
            return;
        timespec ts{};
        clock_gettime(CLOCK_MONOTONIC, &ts);
        m_log.write(QStringLiteral("M %1 %2\n").arg(qint64(ts.tv_sec) * 1000000000LL + ts.tv_nsec).arg(what));
    }

    std::function<void()> onExposed;

    bool eventFilter(QObject *obj, QEvent *event) override {
        if (event->type() == QEvent::Expose) {
            for (auto &w : m_windows) {
                if (w.window != obj)
                    continue;
                if (onExposed && !w.strict)
                    QMetaObject::invokeMethod(this, [this]() { if (onExposed) onExposed(); }, Qt::QueuedConnection);
                // umbriel re-configures the surface (same size) when layers are
                // re-arranged, e.g. as the frame window takes or lets go of the
                // keyboard. Qt takes that as a new expose and renders a frame
                // synchronously on the GUI thread, out of step: a dropped
                // frame of whatever was animating. For a window already shown
                // at that size, a normal (paced) frame does instead. The
                // wallpaper's too: its re-configure as the frame let go of the
                // keyboard landed on the dock's last frames after a close.
                QWindow *win = w.window;
                const QSize size = win->size();
                if (w.shown && size == w.size && win->isExposed()) {
                    win->requestUpdate();
                    return true;
                }
                w.shown = win->isExposed();
                w.size = size;
                return false;
            }
            return false;
        }
        if (event->type() != QEvent::UpdateRequest)
            return false;
        for (auto &w : m_windows) {
            if (w.window != obj)
                continue;
            // A strict window (the wallpaper: its video frames come when
            // they're decoded) draws only just after a tick, so the two
            // windows don't take turns across the refresh.
            const bool early = !w.strict || (monotonicUs() - m_lastTickUs) < 4000;
            if (!isRunning() || (w.allow && early)) {
                w.allow = false;
                return false;
            }
            w.held = true;
            return true;
        }
        return false;
    }

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
        // At rest nothing is held back.
        for (auto &w : m_windows) {
            w.allow = true;
            if (w.held && w.window) {
                w.held = false;
                w.window->requestUpdate();
            }
        }
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
        m_lastTickUs = monotonicUs();
        if (seq)
            m_vblank.handled.storeRelaxed(seq);
        for (auto &w : m_windows)
            w.allow = true;
        advance();
        if (m_logging)
            m_log.step(seq, seq ? us : 0);
        // A request held since the last tick: its frame now.
        for (auto &w : m_windows) {
            if (w.held && w.window) {
                w.held = false;
                w.window->requestUpdate();
            }
        }
        armFallback();
    }

    struct Watched {
        QPointer<QQuickWindow> window;
        bool allow;
        bool held;
        bool strict;
        bool shown = false;
        QSize size;
    };
    qint64 m_lastTickUs = 0;
    QList<Watched> m_windows;
    PresentLog m_log;
    bool m_logChecked = false;
    bool m_logging = false;
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

bool FramePacer::install() {
    if (m_driver)
        return true;
    if (qEnvironmentVariable("NAFEEL_FRAME_PACER") == QLatin1String("0"))
        return false;
    QSGRenderLoop *loop = QSGRenderLoop::instance();
    QAnimationDriver *qtDriver = loop ? loop->animationDriver() : nullptr;
    if (qtDriver)
        qtDriver->uninstall();
    m_driver = new FramePacerDriver();
    m_driver->onExposed = [this]() { emit exposed(); };
    m_driver->install();
    emit activeChanged();
    return true;
}

void FramePacer::attach(QQuickWindow *window) {
    if (window && install())
        m_driver->watch(window);
}

void FramePacer::mark(const QString &what) {
    if (m_driver)
        m_driver->mark(what);
}

void FramePacer::attachWallpaper(QQuickWindow *window) {
    if (window && install())
        m_driver->watch(window, true);
}
