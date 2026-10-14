#include "mpvvideo.h"
#include "framepacer.h"

#include <QGuiApplication>
#include <QOpenGLContext>
#include <QOpenGLFramebufferObject>
#include <QPointer>
#include <QQuickWindow>
#include <QtGui/qguiapplication_platform.h>

#include <clocale>
#include <cmath>
#include <ctime>

#include <mpv/client.h>
#include <mpv/render_gl.h>

namespace {

void *getProcAddress(void *, const char *name) {
    QOpenGLContext *ctx = QOpenGLContext::currentContext();
    return ctx ? reinterpret_cast<void *>(ctx->getProcAddress(name)) : nullptr;
}

// Draws mpv's frame into the item's framebuffer, on the render thread.
class MpvRenderer : public QQuickFramebufferObject::Renderer {
public:
    explicit MpvRenderer(const MpvVideo *item)
        : m_item(const_cast<MpvVideo *>(item)), m_mpv(item->handle()), m_shared(item->shared()) {}

    ~MpvRenderer() override {
        // Before the handle can go (the item may already have).
        QMutexLocker lock(&m_shared->lock);
        if (m_ctx)
            mpv_render_context_free(m_ctx);
        m_shared->ctx = nullptr;
    }

    QOpenGLFramebufferObject *createFramebufferObject(const QSize &size) override {
        if (!m_ctx && m_mpv)
            init();
        return new QOpenGLFramebufferObject(size);
    }

    void render() override {
        if (!m_ctx)
            return;
        QMutexLocker lock(&m_shared->lock);
        QOpenGLFramebufferObject *fbo = framebufferObject();
        mpv_opengl_fbo target{static_cast<int>(fbo->handle()), fbo->width(), fbo->height(), 0};
        int flip = 0;
        // Don't wait for the frame's display time: mpv's own pacing blocked
        // the render thread (~10 ms a frame), dragging everything sharing the
        // window (the lock screen) to the video's 30 fps. The item asks for
        // this frame just before it's due instead (frameQueued).
        int block = 0;
        mpv_render_param params[] = {
            {MPV_RENDER_PARAM_OPENGL_FBO, &target},
            {MPV_RENDER_PARAM_FLIP_Y, &flip},
            {MPV_RENDER_PARAM_BLOCK_FOR_TARGET_TIME, &block},
            {MPV_RENDER_PARAM_INVALID, nullptr},
        };
        mpv_render_context_render(m_ctx, params);
    }

private:
    void init() {
        mpv_opengl_init_params gl{getProcAddress, nullptr};
        // The Wayland display: mpv maps VAAPI frames into GL through it
        // (dmabuf), so a frame never comes back to the CPU.
        void *wl = nullptr;
        if (auto *app = qGuiApp->nativeInterface<QNativeInterface::QWaylandApplication>())
            wl = app->display();
        int advanced = 0;
        mpv_render_param params[] = {
            {MPV_RENDER_PARAM_API_TYPE, const_cast<char *>(MPV_RENDER_API_TYPE_OPENGL)},
            {MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, &gl},
            {MPV_RENDER_PARAM_WL_DISPLAY, wl},
            {MPV_RENDER_PARAM_ADVANCED_CONTROL, &advanced},
            {MPV_RENDER_PARAM_INVALID, nullptr},
        };
        if (!wl)
            params[2] = {MPV_RENDER_PARAM_INVALID, nullptr};
        if (mpv_render_context_create(&m_ctx, m_mpv.get(), params) < 0) {
            m_ctx = nullptr;
            QMetaObject::invokeMethod(m_item, "broken", Qt::QueuedConnection);
            return;
        }
        {
            QMutexLocker lock(&m_shared->lock);
            m_shared->ctx = m_ctx;
        }
        // mpv has a new frame: the item schedules its draw (on its thread).
        QPointer<MpvVideo> item = m_item;
        mpv_render_context_set_update_callback(
            m_ctx,
            [](void *data) {
                auto *p = static_cast<QPointer<MpvVideo> *>(data);
                if (*p)
                    QMetaObject::invokeMethod(p->data(), "frameQueued", Qt::QueuedConnection);
            },
            &m_itemRef);
        m_itemRef = item;
        QMetaObject::invokeMethod(m_item, "contextReady", Qt::QueuedConnection);
    }

    MpvVideo *m_item;
    QPointer<MpvVideo> m_itemRef;
    std::shared_ptr<mpv_handle> m_mpv;
    std::shared_ptr<MpvShared> m_shared;
    mpv_render_context *m_ctx = nullptr;
};

// Where in the refresh before its own a frame is drawn (of the period):
// umbriel (wlroots) showed a commit in the first ~third of a refresh, or
// in the last ~tenth, a refresh late. Measured on 30 fps 4K, 35 s each:
// 0.3 -> 168 late of 570, 0.54 -> 23, 0.6 -> 1-3, 0.78 -> 26, 0.87 -> 99.
// NAFEEL_MPV_PHASE=<percent> overrides it (measuring).
constexpr double kPhase = 0.6;

} // namespace

MpvVideo::MpvVideo(QQuickItem *parent) : QQuickFramebufferObject(parent) {
    m_due.setSingleShot(true);
    m_due.setTimerType(Qt::PreciseTimer);
    connect(&m_due, &QTimer::timeout, this, [this]() { update(); });
    // libmpv refuses to start under a locale whose numbers aren't C's (it
    // parses its options with the C library). Qt and QML use their own
    // locale, so the C library's numeric one can be C.
    std::setlocale(LC_NUMERIC, "C");
    mpv_handle *h = mpv_create();
    if (!h)
        return;
    // A wallpaper: looped, silent, covering the item, decoded on the GPU,
    // nothing it doesn't need (no audio, no subtitles, no input, a small
    // demuxer buffer), downscaled with a sharp but cheap filter.
    for (const auto &[k, v] : {
             std::pair{"vo", "libmpv"},
             {"hwdec", "vaapi"},
             {"hwdec-codecs", "all"},
             {"loop-file", "inf"},
             {"audio", "no"},
             {"mute", "yes"},
             {"sub-auto", "no"},
             {"input-default-bindings", "no"},
             {"input-vo-keyboard", "no"},
             {"osc", "no"},
             {"keepaspect", "yes"},
             {"panscan", "1.0"},
             // mpv's "fast" profile: bilinear scaling (4K to 1080p is an even
             // 2:1, a 2x2 average), no dithering, no linear-light
             // conversions, 8-bit buffers. Its defaults (16-bit float
             // buffers, linear-light Mitchell, dithering) cost 62% of this
             // GPU for a wallpaper.
             {"profile", "fast"},
             {"fbo-format", "rgba8"},
             {"dither", "no"},
             {"interpolation", "no"},
             {"demuxer-max-bytes", "8MiB"},
             {"demuxer-max-back-bytes", "2MiB"},
             {"cache", "no"},
             // The GPU decodes; a CPU decoder thread each only kept its own
             // set of 4K frame contexts (ffmpeg's pools, tens of MB).
             {"vd-lavc-threads", "1"},
             {"hwdec-extra-frames", "2"},
             {"stop-screensaver", "no"},
             {"terminal", "no"},
         })
        mpv_set_option_string(h, k, v);
    // NAFEEL_MPV_OPTS="key=value,key=value": extra mpv options (measuring).
    for (const QByteArray &kv : qgetenv("NAFEEL_MPV_OPTS").split(',')) {
        const int eq = kv.indexOf('=');
        if (eq > 0)
            mpv_set_option_string(h, kv.left(eq).constData(), kv.mid(eq + 1).constData());
    }
    // NAFEEL_MPV_LOG=<file>: mpv's own log (decoder, hardware decoding, VO).
    if (const QByteArray log = qgetenv("NAFEEL_MPV_LOG"); !log.isEmpty()) {
        mpv_set_option_string(h, "log-file", log.constData());
        mpv_set_option_string(h, "msg-level", "all=v");
    }
    if (mpv_initialize(h) < 0) {
        mpv_terminate_destroy(h);
        return;
    }
    m_mpv = std::shared_ptr<mpv_handle>(h, [](mpv_handle *p) { mpv_terminate_destroy(p); });
    // The file's frame rate, for lockSpeed (once per load).
    mpv_observe_property(h, 0, "container-fps", MPV_FORMAT_DOUBLE);
    mpv_set_wakeup_callback(
        h,
        [](void *data) {
            auto *item = static_cast<MpvVideo *>(data);
            QMetaObject::invokeMethod(item, "onEvents", Qt::QueuedConnection);
        },
        this);
}

MpvVideo::~MpvVideo() {
    if (m_mpv)
        mpv_set_wakeup_callback(m_mpv.get(), nullptr, nullptr);
}

QQuickFramebufferObject::Renderer *MpvVideo::createRenderer() const {
    return new MpvRenderer(this);
}

void MpvVideo::setSource(const QString &source) {
    if (source == m_source)
        return;
    m_source = source;
    emit sourceChanged();
    load();
}

void MpvVideo::setPlaying(bool playing) {
    if (playing == m_playing)
        return;
    m_playing = playing;
    emit playingChanged();
    if (m_mpv)
        mpv_set_property_string(m_mpv.get(), "pause", m_playing ? "no" : "yes");
}

void MpvVideo::setStartAt(int ms) {
    if (ms == m_startAt)
        return;
    m_startAt = ms;
    emit startAtChanged();
}

void MpvVideo::contextReady() {
    if (m_context)
        return;
    m_context = true;
    load();
}

void MpvVideo::load() {
    if (!m_mpv || !m_context)
        return;
    if (m_ready) {
        m_ready = false;
        emit readyChanged();
    }
    const QByteArray path = (m_source.startsWith(QLatin1String("file://")) ? m_source.mid(7) : m_source).toUtf8();
    mpv_set_property_string(m_mpv.get(), "pause", m_playing ? "no" : "yes");
    if (path.isEmpty()) {
        const char *cmd[] = {"stop", nullptr};
        mpv_command_async(m_mpv.get(), 0, cmd);
        return;
    }
    const QByteArray start = QByteArray("start=") + QByteArray::number(m_startAt / 1000.0, 'f', 3);
    const char *cmd[] = {"loadfile", path.constData(), "replace", "-1", m_startAt > 0 ? start.constData() : nullptr, nullptr};
    mpv_command_async(m_mpv.get(), 0, cmd);
}

int MpvVideo::position() const {
    double t = 0;
    if (m_mpv && mpv_get_property(m_mpv.get(), "time-pos", MPV_FORMAT_DOUBLE, &t) >= 0)
        return int(t * 1000);
    return m_position;
}

// mpv queues each frame ~50 ms ahead of its time (video-timing-offset) and
// the next one as soon as the last was drawn: drawn on arrival, frames came
// 1, 2 or 3 refreshes apart (61 + 165 + 36 in 10 s of a 30 fps video, where
// every gap should be 2). Each is drawn for the refresh nearest its time
// instead, at a fixed point of the refresh before it (kPhase), well away
// from where a ms of jitter flips it between two.
void MpvVideo::frameQueued() {
    mpv_render_frame_info info{};
    bool known = false;
    // A render is a few ms at most; rather than wait out a long one, draw.
    if (m_shared->lock.tryLock(4)) {
        if (m_shared->ctx) {
            mpv_render_param param{MPV_RENDER_PARAM_NEXT_FRAME_INFO, &info};
            known = mpv_render_context_get_info(m_shared->ctx, param) >= 0;
        }
        m_shared->lock.unlock();
    }
    const bool timed = known && (info.flags & MPV_RENDER_FRAME_INFO_PRESENT)
        && !(info.flags & MPV_RENDER_FRAME_INFO_REDRAW) && info.target_time > 0 && m_mpv;
    qint64 vblank = 0;
    if (!timed || !FramePacer::lastVblank(&vblank)) {
        m_due.stop();
        update();
        return;
    }
    timespec ts{};
    clock_gettime(CLOCK_MONOTONIC, &ts);
    const qint64 now = qint64(ts.tv_sec) * 1000000 + ts.tv_nsec / 1000;
    // In mpv's clock, in ns (its header still says us; the clock moved to ns).
    const qint64 target = now + (info.target_time - mpv_get_time_ns(m_mpv.get())) / 1000;
    const double period = FramePacer::refreshPeriodUs();
    lockSpeed(period);
    const double shown = vblank + std::round((target - vblank) / period) * period;
    static const double phase = qEnvironmentVariableIsSet("NAFEEL_MPV_PHASE") ? qEnvironmentVariableIntValue("NAFEEL_MPV_PHASE") / 100.0 : kPhase;
    const qint64 wait = qint64(shown - period + phase * period) - now;
    if (wait < 1000) {
        m_due.stop();
        update();
        return;
    }
    m_due.start(int(std::min<qint64>(wait / 1000, 1000)));
}

// A 30 fps video on a 60.06 Hz panel: a frame lasts 2.002 refreshes, so
// every ~18 s one was shown for 3. Played 0.1% faster, a frame is exactly
// two refreshes (mpv's display-resample, without its redraw every refresh).
void MpvVideo::lockSpeed(double periodUs) {
    if (m_fps <= 0 || periodUs <= 0)
        return;
    const double hz = 1e6 / periodUs;
    const double k = std::round(hz / m_fps);
    double speed = k >= 1 ? hz / (k * m_fps) : 1;
    if (std::abs(speed - 1) > 0.02)
        speed = 1;
    if (std::abs(speed - m_speed) < 1e-6)
        return;
    m_speed = speed;
    mpv_set_property_async(m_mpv.get(), 0, "speed", MPV_FORMAT_DOUBLE, &speed);
}

void MpvVideo::frameDrawn() {
    if (m_ready)
        return;
    m_ready = true;
    emit readyChanged();
    emit firstFrame();
}

void MpvVideo::onEvents() {
    if (!m_mpv)
        return;
    while (true) {
        mpv_event *ev = mpv_wait_event(m_mpv.get(), 0);
        if (ev->event_id == MPV_EVENT_NONE)
            break;
        switch (ev->event_id) {
        case MPV_EVENT_PROPERTY_CHANGE: {
            auto *prop = static_cast<mpv_event_property *>(ev->data);
            if (qstrcmp(prop->name, "container-fps") == 0) {
                m_fps = prop->format == MPV_FORMAT_DOUBLE ? *static_cast<double *>(prop->data) : 0;
                m_speed = 0;
                lockSpeed(FramePacer::refreshPeriodUs());
                break;
            }
            if (prop->format == MPV_FORMAT_DOUBLE && qstrcmp(prop->name, "time-pos") == 0) {
                const int ms = int(*static_cast<double *>(prop->data) * 1000);
                // Coarse: a QML binding doesn't need 30 updates a second.
                if (qAbs(ms - m_position) >= 500) {
                    m_position = ms;
                    emit positionChanged();
                }
            }
            break;
        }
        // The first frame is ready to show (after a load or a seek).
        case MPV_EVENT_PLAYBACK_RESTART:
            frameDrawn();
            break;
        case MPV_EVENT_END_FILE: {
            auto *end = static_cast<mpv_event_end_file *>(ev->data);
            if (end->reason == MPV_END_FILE_REASON_ERROR)
                emit broken();
            break;
        }
        default:
            break;
        }
    }
}
