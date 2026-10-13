#include "mpvvideo.h"

#include <QGuiApplication>
#include <QOpenGLContext>
#include <QOpenGLFramebufferObject>
#include <QPointer>
#include <QQuickWindow>
#include <QtGui/qguiapplication_platform.h>

#include <clocale>

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
    explicit MpvRenderer(const MpvVideo *item) : m_item(const_cast<MpvVideo *>(item)), m_mpv(item->handle()) {}

    ~MpvRenderer() override {
        // Before the handle can go (the item may already have).
        if (m_ctx)
            mpv_render_context_free(m_ctx);
    }

    QOpenGLFramebufferObject *createFramebufferObject(const QSize &size) override {
        if (!m_ctx && m_mpv)
            init();
        return new QOpenGLFramebufferObject(size);
    }

    void render() override {
        if (!m_ctx)
            return;
        QOpenGLFramebufferObject *fbo = framebufferObject();
        mpv_opengl_fbo target{static_cast<int>(fbo->handle()), fbo->width(), fbo->height(), 0};
        int flip = 0;
        // Don't wait for the frame's display time: mpv's own pacing blocked
        // the render thread (~10 ms a frame), dragging everything sharing the
        // window (the lock screen) to the video's 30 fps. Qt paces at vsync.
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
        // mpv has a new frame: draw again (the item's update, on its thread).
        QPointer<MpvVideo> item = m_item;
        mpv_render_context_set_update_callback(
            m_ctx,
            [](void *data) {
                auto *p = static_cast<QPointer<MpvVideo> *>(data);
                if (*p)
                    QMetaObject::invokeMethod(p->data(), "update", Qt::QueuedConnection);
            },
            &m_itemRef);
        m_itemRef = item;
        QMetaObject::invokeMethod(m_item, "contextReady", Qt::QueuedConnection);
    }

    MpvVideo *m_item;
    QPointer<MpvVideo> m_itemRef;
    std::shared_ptr<mpv_handle> m_mpv;
    mpv_render_context *m_ctx = nullptr;
};

} // namespace

MpvVideo::MpvVideo(QQuickItem *parent) : QQuickFramebufferObject(parent) {
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
