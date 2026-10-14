#include "dmabufvideo.h"
#include "framepacer.h"

#include <QDeadlineTimer>
#include <QHash>
#include <QPair>
#include <QGuiApplication>
#include <QMutex>
#include <QSet>
#include <QThread>
#include <QWaitCondition>
#include <QtGui/qguiapplication_platform.h>
#include <qpa/qplatformnativeinterface.h>

#include <atomic>
#include <cmath>
#include <ctime>
#include <deque>
#include <unordered_map>

#include <wayland-client.h>
#include "linux-dmabuf-v1-client-protocol.h"
#include "viewporter-client-protocol.h"
#include "presentation-time-client-protocol.h"

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

// Where in the refresh before its own a frame is committed (of the period):
// umbriel shows a commit made early in a refresh, or in its last tenth, a
// refresh late (measured for MpvVideo, the same compositor path).
constexpr double kPhase = 0.6;

// The parts of the GUI's state the worker follows.
struct Wanted {
    QString path;
    int startAt = 0;
    bool playing = true;
    bool shown = false;
    wl_surface *parent = nullptr;
    quint64 parentGen = 0;
    QPoint pos;
    QSize logical;
    QSize pixels;
};

struct Decoded {
    AVFrame *frame = nullptr;  // the processed (RGB, screen-sized) frame
    double pts = 0;            // seconds, in the file
};

} // namespace

class DmabufVideoWorker : public QThread {
public:
    DmabufVideoWorker(DmabufVideo *item, wl_display *display) : m_item(item), m_display(display) {}

    ~DmabufVideoWorker() override {
        {
            QMutexLocker lock(&m_lock);
            m_quit = true;
            m_cond.wakeAll();
        }
        wait();
    }

    void set(const Wanted &w) {
        QMutexLocker lock(&m_lock);
        m_want = w;
        m_changed = true;
        m_cond.wakeAll();
    }

    std::atomic<int> positionMs{0};

protected:
    void run() override {
        if (!setupWayland() || av_hwdevice_ctx_create(&m_hw, AV_HWDEVICE_TYPE_VAAPI, nullptr, nullptr, 0) < 0) {
            fail("no VAAPI device or dmabuf support");
            teardown();
            return;
        }
        Wanted have;
        bool broken = false;
        while (true) {
            Wanted w;
            {
                QMutexLocker lock(&m_lock);
                if (m_quit)
                    break;
                w = m_want;
                m_changed = false;
            }
            wl_display_dispatch_queue_pending(m_display, m_queue);

            if (w.parentGen != have.parentGen || w.parent != have.parent) {
                destroySurface();
                if (w.parent)
                    createSurface(w.parent);
            }
            if (w.path != have.path) {
                closeFile();
                broken = false;
                if (!w.path.isEmpty() && !openFile(w.path, w.startAt)) {
                    broken = true;
                    fail("can't open " + w.path);
                }
            }
            if (w.pixels != have.pixels)
                dropGraph();
            if (w.pos != have.pos || w.logical != have.logical || w.parent != have.parent)
                m_geometryDirty = true;
            const bool resumed = w.playing && !have.playing;
            have = w;

            if (broken || !m_surface || !m_fmt || !w.shown || w.pixels.isEmpty()) {
                if (m_attached)
                    detach();
                idle(100);
                continue;
            }
            if (resumed)
                m_anchored = false;
            if (!w.playing && m_attached) {
                m_anchored = false;
                idle(250);
                continue;
            }
            m_pixels = w.pixels;
            m_logical = w.logical;
            m_pos = w.pos;

            // Up to two frames ready ahead.
            while (m_queue_.size() < 2) {
                Decoded d = decodeOne();
                if (!d.frame)
                    break;
                m_queue_.push_back(d);
            }
            if (m_queue_.empty()) {
                broken = true;
                fail("decoding stopped");
                continue;
            }

            const qint64 commitAt = schedule(m_queue_.front());
            const qint64 now = nowUs();
            if (commitAt > now + 300) {
                idle(0, commitAt);
                continue;
            }
            // Late by more than a refresh: let this one go (not the only one).
            if (m_attached && now - commitAt > m_period && m_queue_.size() > 1) {
                av_frame_free(&m_queue_.front().frame);
                m_queue_.pop_front();
                m_index++;
                continue;
            }
            Decoded d = m_queue_.front();
            m_queue_.pop_front();
            present(d);
            // Paused before its first frame: that frame shows, then it holds.
            if (!w.playing)
                m_anchored = false;
        }
        teardown();
    }

private:
    // ── Waiting ──
    // Until `untilUs` (CLOCK_MONOTONIC) or `ms`, or a change from the GUI.
    void idle(int ms, qint64 untilUs = 0) {
        QMutexLocker lock(&m_lock);
        if (m_quit || m_changed)
            return;
        QDeadlineTimer dl(Qt::PreciseTimer);
        if (untilUs)
            dl.setPreciseRemainingTime(0, std::max<qint64>(0, untilUs - nowUs()) * 1000, Qt::PreciseTimer);
        else
            dl.setRemainingTime(ms, Qt::PreciseTimer);
        m_cond.wait(&m_lock, dl);
    }

    void fail(const QString &why) {
        qWarning("DmabufVideo: %s", qPrintable(why));
        QMetaObject::invokeMethod(m_item, "onBroken", Qt::QueuedConnection);
    }

    // ── Wayland ──
    bool setupWayland() {
        m_queue = wl_display_create_queue(m_display);
        auto *wrapped = static_cast<wl_display *>(wl_proxy_create_wrapper(m_display));
        wl_proxy_set_queue(reinterpret_cast<wl_proxy *>(wrapped), m_queue);
        m_registry = wl_display_get_registry(wrapped);
        wl_proxy_wrapper_destroy(wrapped);
        static const wl_registry_listener listener = {
            [](void *data, wl_registry *r, uint32_t name, const char *iface, uint32_t version) {
                auto *self = static_cast<DmabufVideoWorker *>(data);
                if (qstrcmp(iface, wl_compositor_interface.name) == 0)
                    self->m_compositor = static_cast<wl_compositor *>(wl_registry_bind(r, name, &wl_compositor_interface, std::min(version, 4u)));
                else if (qstrcmp(iface, wl_subcompositor_interface.name) == 0)
                    self->m_subcompositor = static_cast<wl_subcompositor *>(wl_registry_bind(r, name, &wl_subcompositor_interface, 1));
                else if (qstrcmp(iface, wp_presentation_interface.name) == 0 && !qEnvironmentVariableIsEmpty("NAFEEL_DMABUF_LOG"))
                    self->m_presentation = static_cast<wp_presentation *>(wl_registry_bind(r, name, &wp_presentation_interface, 1));
                else if (qstrcmp(iface, wp_viewporter_interface.name) == 0)
                    self->m_viewporter = static_cast<wp_viewporter *>(wl_registry_bind(r, name, &wp_viewporter_interface, 1));
                // Version 3: the format and modifier list as plain events.
                else if (qstrcmp(iface, zwp_linux_dmabuf_v1_interface.name) == 0 && version >= 3)
                    self->m_dmabuf = static_cast<zwp_linux_dmabuf_v1 *>(wl_registry_bind(r, name, &zwp_linux_dmabuf_v1_interface, 3));
            },
            [](void *, wl_registry *, uint32_t) {},
        };
        wl_registry_add_listener(m_registry, &listener, this);
        wl_display_roundtrip_queue(m_display, m_queue);
        if (!m_compositor || !m_subcompositor || !m_viewporter || !m_dmabuf)
            return false;
        // NAFEEL_DMABUF_LOG=<file>: "V <ns> <msc>" per frame shown (as the
        // present log's V lines), "D <ns>" per frame never shown.
        if (m_presentation) {
            m_log = fopen(qgetenv("NAFEEL_DMABUF_LOG").constData(), "w");
            if (m_log)
                setvbuf(m_log, nullptr, _IOLBF, 0);
        }
        static const zwp_linux_dmabuf_v1_listener dmabufListener = {
            [](void *, zwp_linux_dmabuf_v1 *, uint32_t) {},
            [](void *data, zwp_linux_dmabuf_v1 *, uint32_t format, uint32_t hi, uint32_t lo) {
                static_cast<DmabufVideoWorker *>(data)->m_formats.insert({format, (quint64(hi) << 32) | lo});
                static_cast<DmabufVideoWorker *>(data)->m_formatOnly.insert(format);
            },
        };
        zwp_linux_dmabuf_v1_add_listener(m_dmabuf, &dmabufListener, this);
        wl_display_roundtrip_queue(m_display, m_queue);
        return !m_formatOnly.isEmpty();
    }

    void createSurface(wl_surface *parent) {
        m_surface = wl_compositor_create_surface(m_compositor);
        m_subsurface = wl_subcompositor_get_subsurface(m_subcompositor, m_surface, parent);
        wl_subsurface_set_desync(m_subsurface);
        wl_subsurface_place_below(m_subsurface, parent);
        // Input goes to the window, not the picture.
        wl_region *none = wl_compositor_create_region(m_compositor);
        wl_surface_set_input_region(m_surface, none);
        wl_region_destroy(none);
        m_viewport = wp_viewporter_get_viewport(m_viewporter, m_surface);
        wl_surface_commit(m_surface);
        m_geometryDirty = true;
        m_attached = false;
        wl_display_flush(m_display);
        // Its place and order take effect with the window's next commit.
        QMetaObject::invokeMethod(m_item, "attachWindow", Qt::QueuedConnection);
    }

    void destroySurface() {
        if (!m_surface)
            return;
        clearBuffers();
        wp_viewport_destroy(m_viewport);
        wl_subsurface_destroy(m_subsurface);
        wl_surface_destroy(m_surface);
        m_viewport = nullptr;
        m_subsurface = nullptr;
        m_surface = nullptr;
        m_attached = false;
        wl_display_flush(m_display);
    }

    void detach() {
        wl_surface_attach(m_surface, nullptr, 0, 0);
        wl_surface_commit(m_surface);
        wl_display_flush(m_display);
        m_attached = false;
        m_anchored = false;
    }

    // A wl_buffer per video-processor surface, made once (the pool reuses
    // them); its frame held until the compositor lets go of it.
    struct Buffer {
        wl_buffer *buffer = nullptr;
        AVFrame *held = nullptr;
        DmabufVideoWorker *self = nullptr;
    };

    Buffer *bufferFor(AVFrame *frame) {
        const auto id = reinterpret_cast<uintptr_t>(frame->data[3]);
        if (auto it = m_buffers.find(id); it != m_buffers.end())
            return it->second.get();
        AVFrame *drm = av_frame_alloc();
        drm->format = AV_PIX_FMT_DRM_PRIME;
        if (av_hwframe_map(drm, frame, AV_HWFRAME_MAP_READ) < 0) {
            av_frame_free(&drm);
            return nullptr;
        }
        const auto *d = reinterpret_cast<const AVDRMFrameDescriptor *>(drm->data[0]);
        if (d->nb_layers != 1) {
            av_frame_free(&drm);
            return nullptr;
        }
        const AVDRMLayerDescriptor &layer = d->layers[0];
        const uint64_t mod = d->objects[layer.planes[0].object_index].format_modifier;
        // Only what the compositor said it takes: a bad one is a protocol
        // error, the whole connection gone.
        if (!m_formats.contains({layer.format, mod}) && !(mod == 0 && m_formatOnly.contains(layer.format))) {
            qWarning("DmabufVideo: format %08x modifier %016llx not offered", layer.format, (unsigned long long)mod);
            av_frame_free(&drm);
            return nullptr;
        }
        zwp_linux_buffer_params_v1 *params = zwp_linux_dmabuf_v1_create_params(m_dmabuf);
        for (int p = 0; p < layer.nb_planes; p++) {
            const AVDRMPlaneDescriptor &pl = layer.planes[p];
            const AVDRMObjectDescriptor &obj = d->objects[pl.object_index];
            zwp_linux_buffer_params_v1_add(params, obj.fd, p, uint32_t(pl.offset), uint32_t(pl.pitch), uint32_t(obj.format_modifier >> 32), uint32_t(obj.format_modifier & 0xffffffff));
        }
        // create (not create_immed): a refusal is an event, not an error.
        struct Result {
            wl_buffer *buffer = nullptr;
            bool done = false;
        } result;
        static const zwp_linux_buffer_params_v1_listener paramsListener = {
            [](void *data, zwp_linux_buffer_params_v1 *, wl_buffer *b) {
                auto *r = static_cast<Result *>(data);
                r->buffer = b;
                r->done = true;
            },
            [](void *data, zwp_linux_buffer_params_v1 *) { static_cast<Result *>(data)->done = true; },
        };
        zwp_linux_buffer_params_v1_add_listener(params, &paramsListener, &result);
        zwp_linux_buffer_params_v1_create(params, frame->width, frame->height, layer.format, 0);
        // The fds were duplicated as the request was written.
        av_frame_free(&drm);
        while (!result.done && wl_display_roundtrip_queue(m_display, m_queue) >= 0) {
        }
        zwp_linux_buffer_params_v1_destroy(params);
        if (!result.buffer) {
            qWarning("DmabufVideo: the compositor refused the buffer");
            return nullptr;
        }
        auto buf = std::make_unique<Buffer>();
        buf->buffer = result.buffer;
        buf->self = this;
        wl_proxy_set_queue(reinterpret_cast<wl_proxy *>(result.buffer), m_queue);
        static const wl_buffer_listener bufferListener = {
            [](void *data, wl_buffer *) {
                auto *b = static_cast<Buffer *>(data);
                if (b->held)
                    av_frame_free(&b->held);
            },
        };
        wl_buffer_add_listener(result.buffer, &bufferListener, buf.get());
        Buffer *raw = buf.get();
        m_buffers.emplace(id, std::move(buf));
        return raw;
    }

    void clearBuffers() {
        if (m_attached && m_surface) {
            wl_surface_attach(m_surface, nullptr, 0, 0);
            wl_surface_commit(m_surface);
            m_attached = false;
        }
        for (auto &[id, b] : m_buffers) {
            wl_buffer_destroy(b->buffer);
            if (b->held)
                av_frame_free(&b->held);
        }
        m_buffers.clear();
        wl_display_flush(m_display);
    }

    void present(Decoded &d) {
        Buffer *b = bufferFor(d.frame);
        if (!b) {
            av_frame_free(&d.frame);
            fail("no dmabuf for the frame");
            closeFile();
            return;
        }
        // Still with the compositor (it never released it): don't reuse.
        if (b->held)
            av_frame_free(&b->held);
        b->held = d.frame;
        if (m_geometryDirty) {
            // Cover: the processed frame is at least the item's size; show
            // its middle, at the item's logical size.
            const int cw = std::min(d.frame->width, m_pixels.width());
            const int ch = std::min(d.frame->height, m_pixels.height());
            wp_viewport_set_source(m_viewport, wl_fixed_from_int((d.frame->width - cw) / 2), wl_fixed_from_int((d.frame->height - ch) / 2), wl_fixed_from_int(cw), wl_fixed_from_int(ch));
            wp_viewport_set_destination(m_viewport, m_logical.width(), m_logical.height());
            wl_subsurface_set_position(m_subsurface, m_pos.x(), m_pos.y());
            m_geometryDirty = false;
        }
        wl_surface_attach(m_surface, b->buffer, 0, 0);
        wl_surface_damage_buffer(m_surface, 0, 0, INT32_MAX, INT32_MAX);
        if (m_log) {
            static const wp_presentation_feedback_listener feedback = {
                [](void *, struct wp_presentation_feedback *, wl_output *) {},
                [](void *data, struct wp_presentation_feedback *fb, uint32_t hi, uint32_t lo, uint32_t ns, uint32_t, uint32_t mhi, uint32_t mlo, uint32_t) {
                    auto *self = static_cast<DmabufVideoWorker *>(data);
                    fprintf(self->m_log, "V %lld %llu\n", (long long)((((qint64(hi) << 32) | lo) * 1000000000LL) + ns), (unsigned long long)((quint64(mhi) << 32) | mlo));
                    self->m_feedbacks.remove(fb);
                    wp_presentation_feedback_destroy(fb);
                },
                [](void *data, struct wp_presentation_feedback *fb) {
                    auto *self = static_cast<DmabufVideoWorker *>(data);
                    fprintf(self->m_log, "D %lld\n", (long long)nowUs() * 1000);
                    self->m_feedbacks.remove(fb);
                    wp_presentation_feedback_destroy(fb);
                },
            };
            struct wp_presentation_feedback *fb = wp_presentation_feedback(m_presentation, m_surface);
            m_feedbacks.insert(fb);
            wp_presentation_feedback_add_listener(fb, &feedback, this);
        }
        wl_surface_commit(m_surface);
        wl_display_flush(m_display);
        if (m_log)
            fprintf(m_log, "C %lld %lld\n", (long long)m_lastCommitAt * 1000, (long long)nowUs() * 1000);
        m_index++;
        positionMs.store(int(std::fmod(d.pts, std::max(m_duration, 0.001)) * 1000), std::memory_order_relaxed);
        if (!m_attached) {
            m_attached = true;
            if (!m_announced) {
                m_announced = true;
                QMetaObject::invokeMethod(m_item, "onFirstFrame", Qt::QueuedConnection);
            }
        }
    }

    // ── Timing ──
    // When to commit this frame (CLOCK_MONOTONIC us).
    qint64 schedule(const Decoded &d) {
        qint64 vblank = 0;
        const bool grid = FramePacer::lastVblank(&vblank);
        m_period = FramePacer::refreshPeriodUs();
        const qint64 now = nowUs();
        if (!grid)
            vblank = now;
        // A frame lasts exactly k refreshes when the rate divides the
        // refresh (within 2%: played that much faster or slower).
        const double hz = 1e6 / m_period;
        const double k = m_fps > 0 ? std::round(hz / m_fps) : 0;
        const bool locked = k >= 1 && std::abs(hz / (k * m_fps) - 1) < 0.02;
        if (!m_anchored) {
            // The first refresh it can make with a commit at kPhase.
            const double lead = m_period * (1 - kPhase) + 1500;
            m_anchor = vblank + std::ceil((now + lead - vblank) / m_period) * m_period;
            m_anchorPts = d.pts;
            m_index = 0;
            m_anchored = true;
            m_sinceResync = 0;
        } else if (grid && ++m_sinceResync > 300) {
            // Keep the grid on the display's own vblanks (the period is
            // measured to ~1 ppm; this takes out what's left).
            m_sinceResync = 0;
            double r = std::fmod(m_anchor - vblank, m_period);
            if (r > m_period / 2)
                r -= m_period;
            else if (r < -m_period / 2)
                r += m_period;
            m_anchor -= r;
        }
        double shown;
        if (locked) {
            shown = m_anchor + double(m_index) * k * m_period;
        } else {
            const double target = m_anchor + (d.pts - m_anchorPts) * 1e6;
            shown = vblank + std::round((target - vblank) / m_period) * m_period;
        }
        static const double phase = qEnvironmentVariableIsSet("NAFEEL_DMABUF_PHASE") ? qEnvironmentVariableIntValue("NAFEEL_DMABUF_PHASE") / 100.0 : kPhase;
        m_lastCommitAt = qint64(shown - m_period + phase * m_period);
        return m_lastCommitAt;
    }

    // ── Decoding ──
    bool openFile(const QString &path, int startAtMs) {
        const QByteArray p = path.toUtf8();
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
        // The processor holds an input frame or two.
        m_dec->extra_hw_frames = 4;
        m_dec->thread_count = 1;
        if (avcodec_open2(m_dec, codec, nullptr) < 0)
            return closeFile(), false;
        m_tb = av_q2d(st->time_base);
        const AVRational rate = av_guess_frame_rate(m_fmt, st, nullptr);
        m_fps = rate.num > 0 && rate.den > 0 ? av_q2d(rate) : 0;
        m_duration = m_fmt->duration > 0 ? m_fmt->duration / double(AV_TIME_BASE) : 0;
        m_loopOffset = 0;
        m_skipUntil = startAtMs > 0 ? startAtMs / 1000.0 : -1;
        if (startAtMs > 0 && m_duration > 0)
            av_seek_frame(m_fmt, -1, int64_t(std::fmod(startAtMs / 1000.0, m_duration) * AV_TIME_BASE), AVSEEK_FLAG_BACKWARD);
        m_pkt = av_packet_alloc();
        m_raw = av_frame_alloc();
        m_draining = false;
        m_anchored = false;
        m_announced = false;
        return true;
    }

    void dropGraph() {
        for (auto &d : m_queue_)
            av_frame_free(&d.frame);
        m_queue_.clear();
        if (m_graph)
            avfilter_graph_free(&m_graph);
        m_src = m_sink = nullptr;
        // Their surfaces go with the graph's pool.
        clearBuffers();
        m_geometryDirty = true;
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

    // The video processor: scale to cover the item, convert to RGB.
    bool buildGraph(const AVFrame *f) {
        const double s = std::max(double(m_pixels.width()) / f->width, double(m_pixels.height()) / f->height);
        const int w = std::max(m_pixels.width(), int(std::ceil(f->width * s / 2)) * 2);
        const int h = std::max(m_pixels.height(), int(std::ceil(f->height * s / 2)) * 2);
        m_graph = avfilter_graph_alloc();
        char args[256];
        AVStream *st = m_fmt->streams[m_stream];
        AVFilterContext *scale = nullptr;
        // The source takes the decoder's frames (VAAPI surfaces): its
        // parameters before it's initialised.
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
        // BT.709, limited range for HD video: the processor's RGB matrix.
        par->color_space = f->colorspace;
        par->color_range = f->color_range;
        const int pe = av_buffersrc_parameters_set(m_src, par);
        av_free(par);
        if (pe < 0 || avfilter_init_str(m_src, nullptr) < 0)
            return false;
        snprintf(args, sizeof args, "w=%d:h=%d:format=bgr0", w, h);
        if (avfilter_graph_create_filter(&scale, avfilter_get_by_name("scale_vaapi"), "scale", args, nullptr, m_graph) < 0)
            return false;
        scale->hw_device_ctx = av_buffer_ref(m_hw);
        // Frames out are held: two queued, two with the compositor.
        scale->extra_hw_frames = 6;
        if (avfilter_graph_create_filter(&m_sink, avfilter_get_by_name("buffersink"), "out", nullptr, nullptr, m_graph) < 0)
            return false;
        if (avfilter_link(m_src, 0, scale, 0) < 0 || avfilter_link(scale, 0, m_sink, 0) < 0)
            return false;
        if (const int e = avfilter_graph_config(m_graph, nullptr); e < 0) {
            failed("configuring the video processor", e);
            return false;
        }
        return true;
    }

    Decoded failed(const char *what, int err) {
        char msg[AV_ERROR_MAX_STRING_SIZE] = "";
        if (err)
            av_strerror(err, msg, sizeof msg);
        qWarning("DmabufVideo: %s failed%s%s", what, err ? ": " : "", msg);
        return {};
    }

    Decoded decodeOne() {
        for (int guard = 0; guard < 4096; guard++) {
            if (m_sink) {
                AVFrame *out = av_frame_alloc();
                const int r = av_buffersink_get_frame(m_sink, out);
                if (r >= 0) {
                    const double pts = (out->best_effort_timestamp != AV_NOPTS_VALUE ? out->best_effort_timestamp : out->pts) * m_tb;
                    return {out, pts + m_loopOffset};
                }
                av_frame_free(&out);
                if (r != AVERROR(EAGAIN))
                    return failed("the video processor", r);
            }
            const int r = avcodec_receive_frame(m_dec, m_raw);
            if (r == 0) {
                const double pts = (m_raw->best_effort_timestamp != AV_NOPTS_VALUE ? m_raw->best_effort_timestamp : m_raw->pts) * m_tb;
                // A handover: from where the other player was.
                if (m_skipUntil >= 0 && pts + 0.001 < std::fmod(m_skipUntil, std::max(m_duration, 0.001))) {
                    av_frame_unref(m_raw);
                    continue;
                }
                m_skipUntil = -1;
                if (!m_graph && !buildGraph(m_raw)) {
                    av_frame_unref(m_raw);
                    return failed("building the video processor", 0);
                }
                if (const int e = av_buffersrc_add_frame_flags(m_src, m_raw, 0); e < 0)
                    return failed("feeding the video processor", e);
                continue;
            }
            if (r == AVERROR_EOF) {
                // Looped: from the top, the clock carrying on.
                av_seek_frame(m_fmt, m_stream, 0, AVSEEK_FLAG_BACKWARD);
                avcodec_flush_buffers(m_dec);
                m_draining = false;
                m_loopOffset += m_duration;
                continue;
            }
            if (r != AVERROR(EAGAIN))
                return failed("the decoder", r);
            if (m_draining)
                continue;
            const int rr = av_read_frame(m_fmt, m_pkt);
            if (rr == AVERROR_EOF) {
                avcodec_send_packet(m_dec, nullptr);
                m_draining = true;
                continue;
            }
            if (rr < 0)
                return failed("reading the file", rr);
            if (m_pkt->stream_index == m_stream)
                avcodec_send_packet(m_dec, m_pkt);
            av_packet_unref(m_pkt);
        }
        return {};
    }

    void teardown() {
        if (qEnvironmentVariableIsSet("NAFEEL_DMABUF_LOG"))
            qWarning("DmabufVideo: worker stopping");
        closeFile();
        destroySurface();
        // Nothing of ours may be left on the queue when it goes: an event for
        // it would abort the process (libwayland).
        for (auto *fb : std::as_const(m_feedbacks))
            wp_presentation_feedback_destroy(fb);
        m_feedbacks.clear();
        if (m_hw)
            av_buffer_unref(&m_hw);
        if (m_viewporter)
            wp_viewporter_destroy(m_viewporter);
        if (m_presentation)
            wp_presentation_destroy(m_presentation);
        if (m_log)
            fclose(m_log);
        if (m_dmabuf)
            zwp_linux_dmabuf_v1_destroy(m_dmabuf);
        if (m_subcompositor)
            wl_subcompositor_destroy(m_subcompositor);
        if (m_compositor)
            wl_compositor_destroy(m_compositor);
        if (m_registry)
            wl_registry_destroy(m_registry);
        wl_display_flush(m_display);
        if (m_queue)
            wl_event_queue_destroy(m_queue);
    }

    DmabufVideo *m_item;
    wl_display *m_display;

    QMutex m_lock;
    QWaitCondition m_cond;
    Wanted m_want;
    bool m_changed = false;
    bool m_quit = false;

    wl_event_queue *m_queue = nullptr;
    wl_registry *m_registry = nullptr;
    wl_compositor *m_compositor = nullptr;
    wl_subcompositor *m_subcompositor = nullptr;
    wp_viewporter *m_viewporter = nullptr;
    zwp_linux_dmabuf_v1 *m_dmabuf = nullptr;
    wp_presentation *m_presentation = nullptr;
    QSet<struct wp_presentation_feedback *> m_feedbacks;
    FILE *m_log = nullptr;
    QSet<QPair<uint32_t, quint64>> m_formats;
    QSet<uint32_t> m_formatOnly;
    wl_surface *m_surface = nullptr;
    wl_subsurface *m_subsurface = nullptr;
    wp_viewport *m_viewport = nullptr;
    std::unordered_map<uintptr_t, std::unique_ptr<Buffer>> m_buffers;
    bool m_attached = false;
    bool m_announced = false;
    bool m_geometryDirty = true;
    QSize m_pixels;
    QSize m_logical;
    QPoint m_pos;

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
    double m_fps = 0;
    double m_duration = 0;
    double m_loopOffset = 0;
    double m_skipUntil = -1;
    bool m_draining = false;
    std::deque<Decoded> m_queue_;

    bool m_anchored = false;
    double m_anchor = 0;
    double m_anchorPts = 0;
    double m_period = 1e6 / 60;
    qint64 m_lastCommitAt = 0;
    qint64 m_index = 0;
    int m_sinceResync = 0;
};

DmabufVideo::DmabufVideo(QQuickItem *parent) : QQuickItem(parent) {
    // The screen's nominal rate read here, on the GUI thread.
    FramePacer::refreshPeriodUs();
    connect(this, &QQuickItem::windowChanged, this, &DmabufVideo::attachWindow);
}

DmabufVideo::~DmabufVideo() {
    if (qEnvironmentVariableIsSet("NAFEEL_DMABUF_LOG"))
        qWarning("DmabufVideo: item destroyed");
    m_worker.reset();
}

void DmabufVideo::attachWindow() {
    QQuickWindow *w = window();
    if (w != m_window) {
        if (m_window)
            disconnect(m_window, nullptr, this, nullptr);
        m_window = w;
        if (w) {
            connect(w, &QWindow::visibleChanged, this, &DmabufVideo::push);
            connect(w, &QWindow::widthChanged, this, &DmabufVideo::push);
            connect(w, &QWindow::heightChanged, this, &DmabufVideo::push);
            // The surface exists once the window has drawn (until then).
            connect(w, &QQuickWindow::frameSwapped, this, [this]() {
                if (!m_haveParent)
                    push();
            }, Qt::QueuedConnection);
        }
    }
    if (m_window)
        m_window->requestUpdate();
    push();
}

void DmabufVideo::push() {
    if (!m_worker) {
        auto *app = qGuiApp->nativeInterface<QNativeInterface::QWaylandApplication>();
        if (!app || !app->display())
            return;
        m_worker = std::make_unique<DmabufVideoWorker>(this, app->display());
        m_worker->setObjectName(QStringLiteral("DmabufVideo"));
        m_worker->start();
    }
    Wanted w;
    w.path = m_source.startsWith(QLatin1String("file://")) ? m_source.mid(7) : m_source;
    w.startAt = m_startAt;
    w.playing = m_playing;
    w.shown = isVisible() && m_window && m_window->isVisible();
    if (m_window && m_window->handle() && w.shown) {
        auto *native = QGuiApplication::platformNativeInterface();
        w.parent = static_cast<wl_surface *>(native->nativeResourceForWindow("surface", m_window));
    }
    m_haveParent = w.parent != nullptr;
    // A new surface for the same window (hidden and shown again) is a new parent.
    static std::atomic<quint64> gen{1};
    static QHash<const void *, quint64> gens;
    if (w.parent) {
        auto it = gens.find(w.parent);
        if (it == gens.end())
            it = gens.insert(w.parent, gen++);
        w.parentGen = it.value();
    }
    const QPointF at = mapToScene(QPointF(0, 0));
    w.pos = at.toPoint();
    w.logical = size().toSize();
    const qreal dpr = m_window ? m_window->effectiveDevicePixelRatio() : 1;
    w.pixels = (size() * dpr).toSize();
    m_worker->set(w);
}

void DmabufVideo::setSource(const QString &source) {
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

void DmabufVideo::setPlaying(bool playing) {
    if (playing == m_playing)
        return;
    m_playing = playing;
    emit playingChanged();
    push();
}

void DmabufVideo::setStartAt(int ms) {
    if (ms == m_startAt)
        return;
    m_startAt = ms;
    emit startAtChanged();
}

int DmabufVideo::position() const {
    return m_worker ? m_worker->positionMs.load(std::memory_order_relaxed) : 0;
}

void DmabufVideo::itemChange(ItemChange change, const ItemChangeData &data) {
    QQuickItem::itemChange(change, data);
    if (change == ItemVisibleHasChanged)
        push();
}

void DmabufVideo::geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry) {
    QQuickItem::geometryChange(newGeometry, oldGeometry);
    push();
}

void DmabufVideo::onFirstFrame() {
    if (m_ready)
        return;
    m_ready = true;
    emit readyChanged();
    emit firstFrame();
}

void DmabufVideo::onBroken() {
    emit broken();
}
