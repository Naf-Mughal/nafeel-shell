#include "scenevideo.h"

#include <QDeadlineTimer>
#include <QOpenGLContext>
#include <QOpenGLFunctions>
#include <QPointer>
#include <QQuickWindow>
#include <QSGSimpleTextureNode>
#include <QHash>

#include <drm_fourcc.h>
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>

#include <cmath>
#include <ctime>
#include <deque>
#include <utility>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavfilter/avfilter.h>
#include <libavfilter/buffersink.h>
#include <libavfilter/buffersrc.h>
#include <libavformat/avformat.h>
#include <libavutil/hwcontext.h>
#include <libavutil/hwcontext_drm.h>
}

namespace {

qint64 nowUs() {
    timespec ts{};
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return qint64(ts.tv_sec) * 1000000 + ts.tv_nsec / 1000;
}

} // namespace

// ── Decoding (its own thread) ───────────────────────────────────────────

class SceneVideoWorker : public QThread {
public:
    explicit SceneVideoWorker(SceneVideo *item) : m_item(item) {}
    ~SceneVideoWorker() override {
        {
            QMutexLocker lock(&m_lock);
            m_quit = true;
            m_cond.wakeAll();
        }
        wait();
    }

    void set(const QString &path, bool playing, QSize pixels) {
        QMutexLocker lock(&m_lock);
        m_wantPath = path;
        m_wantPlaying = playing;
        m_wantPixels = pixels;
        m_changed = true;
        m_cond.wakeAll();
    }

protected:
    void run() override {
        if (av_hwdevice_ctx_create(&m_hw, AV_HWDEVICE_TYPE_VAAPI, nullptr, nullptr, 0) < 0) {
            fail("no VAAPI device");
            return;
        }
        QString path;
        QSize pixels;
        bool playing = true;
        while (true) {
            {
                QMutexLocker lock(&m_lock);
                if (m_quit)
                    break;
                if (m_changed) {
                    if (m_wantPath != path) {
                        closeFile();
                        path = m_wantPath;
                        if (!path.isEmpty() && !openFile(path))
                            fail("can't open " + path);
                    }
                    if (m_wantPixels != pixels) {
                        dropGraph();
                        pixels = m_wantPixels;
                    }
                    if (m_wantPlaying && !playing)
                        m_anchor = 0;
                    playing = m_wantPlaying;
                    m_changed = false;
                }
                if (!m_fmt || !playing || pixels.isEmpty() || m_broken) {
                    m_anchor = 0;
                    m_cond.wait(&m_lock);
                    continue;
                }
            }
            m_pixels = pixels;
            AVFrame *f = nullptr;
            const double pts = decodeOne(&f);
            if (!f) {
                m_broken = true;
                fail("decoding stopped");
                continue;
            }
            // On the file's own clock from where it (re)started.
            const qint64 now = nowUs();
            if (!m_anchor || pts * 1e6 + m_anchor < now - 200000)
                m_anchor = now - qint64(pts * 1e6);
            const qint64 due = m_anchor + qint64(pts * 1e6);
            {
                QMutexLocker lock(&m_lock);
                if (due > nowUs() + 1000 && !m_quit && !m_changed) {
                    QDeadlineTimer dl(Qt::PreciseTimer);
                    dl.setPreciseRemainingTime(0, (due - nowUs()) * 1000, Qt::PreciseTimer);
                    m_cond.wait(&m_lock, dl);
                }
                if (m_quit || m_changed) {
                    av_frame_free(&f);
                    continue;
                }
            }
            QPointer<SceneVideo> item = m_item;
            if (item)
                QMetaObject::invokeMethod(item, "takeFrame", Qt::QueuedConnection, Q_ARG(void *, f));
            else
                av_frame_free(&f);
        }
        closeFile();
        av_buffer_unref(&m_hw);
    }

private:
    void fail(const QString &why) {
        qWarning("SceneVideo: %s", qPrintable(why));
        QPointer<SceneVideo> item = m_item;
        if (item)
            QMetaObject::invokeMethod(item, "onBroken", Qt::QueuedConnection);
    }

    bool openFile(const QString &path) {
        const QByteArray p = (path.startsWith(QLatin1String("file://")) ? path.mid(7) : path).toUtf8();
        if (avformat_open_input(&m_fmt, p.constData(), nullptr, nullptr) < 0) {
            m_fmt = nullptr;
            return false;
        }
        if (avformat_find_stream_info(m_fmt, nullptr) < 0)
            return closeFile(), false;
        const AVCodec *codec = nullptr;
        m_stream = av_find_best_stream(m_fmt, AVMEDIA_TYPE_VIDEO, -1, -1, &codec, 0);
        if (m_stream < 0 || !codec)
            return closeFile(), false;
        AVStream *st = m_fmt->streams[m_stream];
        m_dec = avcodec_alloc_context3(codec);
        avcodec_parameters_to_context(m_dec, st->codecpar);
        m_dec->hw_device_ctx = av_buffer_ref(m_hw);
        m_dec->get_format = [](AVCodecContext *, const AVPixelFormat *fmts) {
            for (const AVPixelFormat *f = fmts; *f != AV_PIX_FMT_NONE; f++)
                if (*f == AV_PIX_FMT_VAAPI)
                    return *f;
            return AV_PIX_FMT_NONE;
        };
        m_dec->extra_hw_frames = 2;
        m_dec->thread_count = 1;
        if (avcodec_open2(m_dec, codec, nullptr) < 0)
            return closeFile(), false;
        m_tb = av_q2d(st->time_base);
        m_duration = m_fmt->duration > 0 ? m_fmt->duration / double(AV_TIME_BASE) : 0;
        m_loopOffset = 0;
        m_pkt = av_packet_alloc();
        m_raw = av_frame_alloc();
        m_draining = false;
        m_broken = false;
        m_anchor = 0;
        return true;
    }

    void dropGraph() {
        if (m_graph)
            avfilter_graph_free(&m_graph);
        m_src = m_sink = nullptr;
    }

    void closeFile() {
        dropGraph();
        if (m_dec)
            avcodec_free_context(&m_dec);
        if (m_fmt)
            avformat_close_input(&m_fmt);
        if (m_pkt)
            av_packet_free(&m_pkt);
        if (m_raw)
            av_frame_free(&m_raw);
        m_stream = -1;
    }

    // The video processor: scale to cover the size it's drawn at, RGB.
    bool buildGraph(const AVFrame *f) {
        const double s = std::max(double(m_pixels.width()) / f->width, double(m_pixels.height()) / f->height);
        const int w = std::max(2, int(std::ceil(f->width * s / 2)) * 2);
        const int h = std::max(2, int(std::ceil(f->height * s / 2)) * 2);
        m_graph = avfilter_graph_alloc();
        AVStream *st = m_fmt->streams[m_stream];
        m_src = avfilter_graph_alloc_filter(m_graph, avfilter_get_by_name("buffer"), "in");
        if (!m_src)
            return false;
        AVBufferSrcParameters *par = av_buffersrc_parameters_alloc();
        par->format = AV_PIX_FMT_VAAPI;
        par->width = f->width;
        par->height = f->height;
        par->time_base = st->time_base;
        par->sample_aspect_ratio = AVRational{1, 1};
        par->hw_frames_ctx = f->hw_frames_ctx;
        par->color_space = f->colorspace;
        par->color_range = f->color_range;
        const int pe = av_buffersrc_parameters_set(m_src, par);
        av_free(par);
        if (pe < 0 || avfilter_init_str(m_src, nullptr) < 0)
            return false;
        char args[128];
        snprintf(args, sizeof args, "w=%d:h=%d:format=bgr0", w, h);
        AVFilterContext *scale = nullptr;
        if (avfilter_graph_create_filter(&scale, avfilter_get_by_name("scale_vaapi"), "scale", args, nullptr, m_graph) < 0)
            return false;
        scale->hw_device_ctx = av_buffer_ref(m_hw);
        // Held at once: the one queued, the one shown, the one before it.
        scale->extra_hw_frames = 4;
        if (avfilter_graph_create_filter(&m_sink, avfilter_get_by_name("buffersink"), "out", nullptr, nullptr, m_graph) < 0)
            return false;
        if (avfilter_link(m_src, 0, scale, 0) < 0 || avfilter_link(scale, 0, m_sink, 0) < 0)
            return false;
        return avfilter_graph_config(m_graph, nullptr) >= 0;
    }

    // The next processed frame and its time (s, looped on), or none.
    double decodeOne(AVFrame **out) {
        *out = nullptr;
        for (int guard = 0; guard < 4096; guard++) {
            if (m_sink) {
                AVFrame *o = av_frame_alloc();
                const int r = av_buffersink_get_frame(m_sink, o);
                if (r >= 0) {
                    const double pts = (o->best_effort_timestamp != AV_NOPTS_VALUE ? o->best_effort_timestamp : o->pts) * m_tb;
                    *out = o;
                    return pts + m_loopOffset;
                }
                av_frame_free(&o);
                if (r != AVERROR(EAGAIN))
                    return 0;
            }
            const int r = avcodec_receive_frame(m_dec, m_raw);
            if (r == 0) {
                if (!m_graph && !buildGraph(m_raw)) {
                    av_frame_unref(m_raw);
                    return 0;
                }
                if (av_buffersrc_add_frame_flags(m_src, m_raw, 0) < 0)
                    return 0;
                continue;
            }
            if (r == AVERROR_EOF) {
                av_seek_frame(m_fmt, m_stream, 0, AVSEEK_FLAG_BACKWARD);
                avcodec_flush_buffers(m_dec);
                m_draining = false;
                m_loopOffset += m_duration;
                continue;
            }
            if (r != AVERROR(EAGAIN))
                return 0;
            if (m_draining)
                continue;
            const int rr = av_read_frame(m_fmt, m_pkt);
            if (rr == AVERROR_EOF) {
                avcodec_send_packet(m_dec, nullptr);
                m_draining = true;
                continue;
            }
            if (rr < 0)
                return 0;
            if (m_pkt->stream_index == m_stream)
                avcodec_send_packet(m_dec, m_pkt);
            av_packet_unref(m_pkt);
        }
        return 0;
    }

    QPointer<SceneVideo> m_item;
    QMutex m_lock;
    QWaitCondition m_cond;
    bool m_quit = false;
    bool m_changed = false;
    QString m_wantPath;
    bool m_wantPlaying = true;
    QSize m_wantPixels;

    AVBufferRef *m_hw = nullptr;
    AVFormatContext *m_fmt = nullptr;
    AVCodecContext *m_dec = nullptr;
    AVFilterGraph *m_graph = nullptr;
    AVFilterContext *m_src = nullptr;
    AVFilterContext *m_sink = nullptr;
    AVPacket *m_pkt = nullptr;
    AVFrame *m_raw = nullptr;
    int m_stream = -1;
    double m_tb = 0;
    double m_duration = 0;
    double m_loopOffset = 0;
    bool m_draining = false;
    bool m_broken = false;
    qint64 m_anchor = 0;
    QSize m_pixels;
};

// ── Showing (render thread) ─────────────────────────────────────────────

class SceneVideoNode : public QObject, public QSGSimpleTextureNode {
public:
    SceneVideoNode(SceneVideo *item, QQuickWindow *window) : m_item(item), m_window(window) {
        setOwnsTexture(false);
        setFiltering(QSGTexture::Linear);
        connect(window, &QQuickWindow::beforeRendering, this, &SceneVideoNode::render, Qt::DirectConnection);
    }

    ~SceneVideoNode() override {
        // The scene graph's context is current while its nodes go.
        auto *gl = QOpenGLContext::currentContext() ? QOpenGLContext::currentContext()->functions() : nullptr;
        static auto destroyImage = reinterpret_cast<PFNEGLDESTROYIMAGEKHRPROC>(eglGetProcAddress("eglDestroyImageKHR"));
        for (auto &s : m_surfaces) {
            delete s.texture;
            if (gl)
                gl->glDeleteTextures(1, &s.id);
            if (destroyImage && s.image != EGL_NO_IMAGE_KHR)
                destroyImage(s.display, s.image);
        }
        for (AVFrame *f : {m_pending, m_shown, m_before})
            if (f)
                av_frame_free(&f);
    }

    // Sync: the newest frame to show (taken over) and where it's drawn.
    void sync(AVFrame *frame, QRectF rect, QSize pixels) {
        if (frame) {
            if (m_pending)
                av_frame_free(&m_pending);
            m_pending = frame;
        }
        m_rect = rect;
        m_pixels = pixels;
        setRect(rect);
    }

private:
    struct Surface {
        EGLDisplay display = EGL_NO_DISPLAY;
        EGLImageKHR image = EGL_NO_IMAGE_KHR;
        GLuint id = 0;
        QSGTexture *texture = nullptr;
    };

    void render() {
        if (!m_pending)
            return;
        AVFrame *f = m_pending;
        m_pending = nullptr;
        const auto key = reinterpret_cast<quintptr>(f->data[3]);
        auto it = m_surfaces.find(key);
        if (it == m_surfaces.end()) {
            m_window->beginExternalCommands();
            Surface s = import(f);
            m_window->endExternalCommands();
            if (!s.texture) {
                av_frame_free(&f);
                QMetaObject::invokeMethod(m_item, "onBroken", Qt::QueuedConnection);
                return;
            }
            it = m_surfaces.insert(key, s);
        }
        setTexture(it->texture);
        // Cover: the frame is at least the size it's drawn at; its middle.
        const qreal cw = std::min<qreal>(f->width, m_pixels.width()), ch = std::min<qreal>(f->height, m_pixels.height());
        setSourceRect(QRectF((f->width - cw) / 2, (f->height - ch) / 2, cw, ch));
        markDirty(QSGNode::DirtyMaterial);
        // The one before may still be read by the frame that showed it.
        if (m_before)
            av_frame_free(&m_before);
        m_before = m_shown;
        m_shown = f;
    }

    Surface import(AVFrame *frame) {
        Surface s;
        static auto createImage = reinterpret_cast<PFNEGLCREATEIMAGEKHRPROC>(eglGetProcAddress("eglCreateImageKHR"));
        static auto target = reinterpret_cast<PFNGLEGLIMAGETARGETTEXTURE2DOESPROC>(eglGetProcAddress("glEGLImageTargetTexture2DOES"));
        auto *ctx = QOpenGLContext::currentContext();
        if (!createImage || !target || !ctx)
            return s;
        AVFrame *drm = av_frame_alloc();
        drm->format = AV_PIX_FMT_DRM_PRIME;
        if (av_hwframe_map(drm, frame, AV_HWFRAME_MAP_READ) < 0) {
            av_frame_free(&drm);
            return s;
        }
        const auto *d = reinterpret_cast<const AVDRMFrameDescriptor *>(drm->data[0]);
        if (d->nb_layers != 1 || d->layers[0].nb_planes != 1) {
            av_frame_free(&drm);
            return s;
        }
        const AVDRMLayerDescriptor &layer = d->layers[0];
        const AVDRMPlaneDescriptor &pl = layer.planes[0];
        const AVDRMObjectDescriptor &obj = d->objects[pl.object_index];
        QList<EGLint> attrs = {
            EGL_WIDTH, frame->width,
            EGL_HEIGHT, frame->height,
            EGL_LINUX_DRM_FOURCC_EXT, EGLint(layer.format),
            EGL_DMA_BUF_PLANE0_FD_EXT, obj.fd,
            EGL_DMA_BUF_PLANE0_OFFSET_EXT, EGLint(pl.offset),
            EGL_DMA_BUF_PLANE0_PITCH_EXT, EGLint(pl.pitch),
        };
        if (obj.format_modifier != DRM_FORMAT_MOD_INVALID) {
            attrs << EGL_DMA_BUF_PLANE0_MODIFIER_LO_EXT << EGLint(obj.format_modifier & 0xffffffff)
                  << EGL_DMA_BUF_PLANE0_MODIFIER_HI_EXT << EGLint(obj.format_modifier >> 32);
        }
        attrs << EGL_NONE;
        s.display = eglGetCurrentDisplay();
        // The image holds its own reference to the buffer: the mapping can go.
        s.image = createImage(s.display, EGL_NO_CONTEXT, EGL_LINUX_DMA_BUF_EXT, nullptr, attrs.constData());
        av_frame_free(&drm);
        if (s.image == EGL_NO_IMAGE_KHR)
            return s;
        QOpenGLFunctions *gl = ctx->functions();
        gl->glGenTextures(1, &s.id);
        gl->glBindTexture(GL_TEXTURE_2D, s.id);
        target(GL_TEXTURE_2D, s.image);
        gl->glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        gl->glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        gl->glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        gl->glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        gl->glBindTexture(GL_TEXTURE_2D, 0);
        s.texture = QNativeInterface::QSGOpenGLTexture::fromNative(s.id, m_window, QSize(frame->width, frame->height));
        return s;
    }

    QPointer<SceneVideo> m_item;
    QQuickWindow *m_window;
    QHash<quintptr, Surface> m_surfaces;
    AVFrame *m_pending = nullptr;
    AVFrame *m_shown = nullptr;
    AVFrame *m_before = nullptr;
    QRectF m_rect;
    QSize m_pixels;
};

// ── The item ──────────────────────────────────────────────────────────────

SceneVideo::SceneVideo(QQuickItem *parent) : QQuickItem(parent) {
    setFlag(ItemHasContents);
}

SceneVideo::~SceneVideo() {
    delete m_worker;
    if (m_next)
        av_frame_free(&m_next);
}

void SceneVideo::setSource(const QString &source) {
    if (source == m_source)
        return;
    m_source = source;
    if (m_ready) {
        m_ready = false;
        emit readyChanged();
    }
    emit sourceChanged();
    push();
}

void SceneVideo::setPlaying(bool playing) {
    if (playing == m_playing)
        return;
    m_playing = playing;
    emit playingChanged();
    push();
}

void SceneVideo::setResolution(qreal r) {
    r = std::clamp(r, 0.05, 1.0);
    if (qFuzzyCompare(r, m_resolution))
        return;
    m_resolution = r;
    emit resolutionChanged();
    push();
}

void SceneVideo::geometryChange(const QRectF &n, const QRectF &o) {
    QQuickItem::geometryChange(n, o);
    if (n.size() != o.size())
        push();
}

void SceneVideo::itemChange(ItemChange change, const ItemChangeData &data) {
    QQuickItem::itemChange(change, data);
    if (change == ItemSceneChange)
        push();
}

// What the worker should do now.
void SceneVideo::push() {
    const qreal dpr = window() ? window()->effectiveDevicePixelRatio() : 1;
    const QSize pixels(qRound(width() * dpr * m_resolution), qRound(height() * dpr * m_resolution));
    // In a window, visible or not: an item drawn through a capture (a
    // ShaderEffectSource with hideSource) is hidden yet shown; `playing`
    // says when to play.
    const bool shown = window() != nullptr;
    if (!m_worker) {
        if (m_source.isEmpty() || !shown)
            return;
        m_worker = new SceneVideoWorker(this);
        m_worker->start();
    }
    m_worker->set(m_source, m_playing && shown, pixels);
}

void SceneVideo::takeFrame(void *frame) {
    auto *f = static_cast<AVFrame *>(frame);
    if (m_next)
        av_frame_free(&m_next);
    m_next = f;
    update();
    if (!m_ready) {
        m_ready = true;
        emit readyChanged();
        emit firstFrame();
    }
    emit this->frame();
}

void SceneVideo::onBroken() {
    emit broken();
}

QSGNode *SceneVideo::updatePaintNode(QSGNode *old, UpdatePaintNodeData *) {
    if (!window())
        return old;
    auto *node = static_cast<SceneVideoNode *>(old);
    if (!node) {
        if (!m_next)
            return nullptr;
        node = new SceneVideoNode(this, window());
    }
    const qreal dpr = window()->effectiveDevicePixelRatio();
    node->sync(std::exchange(m_next, nullptr), boundingRect(), QSize(qRound(width() * dpr * m_resolution), qRound(height() * dpr * m_resolution)));
    // Its texture is set just before the scene draws (render()).
    return node;
}
