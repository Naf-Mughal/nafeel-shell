#include "capture.h"

#include <QDebug>
#include <QSocketNotifier>

#include <cerrno>
#include <cstring>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>

#include <wayland-client.h>

#include "ext-foreign-toplevel-list-v1-client-protocol.h"
#include "ext-image-capture-source-v1-client-protocol.h"
#include "ext-image-copy-capture-v1-client-protocol.h"

// The protocol callbacks, as friends of the classes they feed.
struct CaptureListeners {
    // ── Registry ──────────────────────────────────────────────────────────

    static void global(void *data, wl_registry *reg, uint32_t name, const char *iface, uint32_t version) {
        auto *c = static_cast<Capture *>(data);
        if (strcmp(iface, wl_shm_interface.name) == 0)
            c->m_shm = static_cast<wl_shm *>(wl_registry_bind(reg, name, &wl_shm_interface, 1));
        else if (strcmp(iface, ext_foreign_toplevel_list_v1_interface.name) == 0)
            c->m_list = static_cast<ext_foreign_toplevel_list_v1 *>(
                wl_registry_bind(reg, name, &ext_foreign_toplevel_list_v1_interface, 1));
        else if (strcmp(iface, ext_image_copy_capture_manager_v1_interface.name) == 0)
            c->m_copyManager = static_cast<ext_image_copy_capture_manager_v1 *>(
                wl_registry_bind(reg, name, &ext_image_copy_capture_manager_v1_interface, 1));
        else if (strcmp(iface, ext_foreign_toplevel_image_capture_source_manager_v1_interface.name) == 0)
            c->m_sourceManager = static_cast<ext_foreign_toplevel_image_capture_source_manager_v1 *>(
                wl_registry_bind(reg, name, &ext_foreign_toplevel_image_capture_source_manager_v1_interface, 1));
    }
    static void globalRemove(void *, wl_registry *, uint32_t) {}
    static constexpr wl_registry_listener registry{global, globalRemove};

    // ── Window list ───────────────────────────────────────────────────────

    static void toplevel(void *data, ext_foreign_toplevel_list_v1 *, ext_foreign_toplevel_handle_v1 *handle) {
        auto *t = new Capture::Toplevel{static_cast<Capture *>(data), handle, {}};
        ext_foreign_toplevel_handle_v1_add_listener(handle, &toplevelHandle, t);
    }
    static void finished(void *, ext_foreign_toplevel_list_v1 *) {}
    static constexpr ext_foreign_toplevel_list_v1_listener list{toplevel, finished};

    static void tlClosed(void *data, ext_foreign_toplevel_handle_v1 *) {
        auto *t = static_cast<Capture::Toplevel *>(data);
        t->owner->toplevelClosed(t);
    }
    static void tlDone(void *data, ext_foreign_toplevel_handle_v1 *) {
        auto *t = static_cast<Capture::Toplevel *>(data);
        t->owner->toplevelDone(t);
    }
    static void tlTitle(void *, ext_foreign_toplevel_handle_v1 *, const char *) {}
    static void tlAppId(void *, ext_foreign_toplevel_handle_v1 *, const char *) {}
    static void tlIdentifier(void *data, ext_foreign_toplevel_handle_v1 *, const char *id) {
        static_cast<Capture::Toplevel *>(data)->id = QString::fromUtf8(id);
    }
    static constexpr ext_foreign_toplevel_handle_v1_listener toplevelHandle{tlClosed, tlDone, tlTitle, tlAppId,
                                                                           tlIdentifier};

    // ── Capture session ───────────────────────────────────────────────────

    static CaptureSession *s(void *data) { return static_cast<CaptureSession *>(data); }

    static void bufferSize(void *data, ext_image_copy_capture_session_v1 *, uint32_t w, uint32_t h) {
        s(data)->m_offerSize = QSize(int(w), int(h));
    }
    static void shmFormat(void *data, ext_image_copy_capture_session_v1 *, uint32_t format) {
        // The 32-bit BGRx/BGRA layouts read as QImage::Format_RGB32; XRGB first.
        auto *session = s(data);
        if (format != WL_SHM_FORMAT_XRGB8888 && format != WL_SHM_FORMAT_ARGB8888)
            return;
        if (!session->m_offerHasFormat || format == WL_SHM_FORMAT_XRGB8888)
            session->m_offerFormat = format;
        session->m_offerHasFormat = true;
    }
    static void dmabufDevice(void *, ext_image_copy_capture_session_v1 *, wl_array *) {}
    static void dmabufFormat(void *, ext_image_copy_capture_session_v1 *, uint32_t, wl_array *) {}
    static void sessionDone(void *data, ext_image_copy_capture_session_v1 *) { s(data)->constraintsDone(); }
    static void sessionStopped(void *data, ext_image_copy_capture_session_v1 *) { s(data)->stop(); }
    static constexpr ext_image_copy_capture_session_v1_listener session{bufferSize,   shmFormat,   dmabufDevice,
                                                                        dmabufFormat, sessionDone, sessionStopped};

    static void transform(void *, ext_image_copy_capture_frame_v1 *, uint32_t) {}
    static void damage(void *, ext_image_copy_capture_frame_v1 *, int32_t, int32_t, int32_t, int32_t) {}
    static void presentationTime(void *, ext_image_copy_capture_frame_v1 *, uint32_t, uint32_t, uint32_t) {}
    static void ready(void *data, ext_image_copy_capture_frame_v1 *) { s(data)->frameReady(); }
    static void failed(void *data, ext_image_copy_capture_frame_v1 *, uint32_t reason) { s(data)->frameFailed(reason); }
    static constexpr ext_image_copy_capture_frame_v1_listener frame{transform, damage, presentationTime, ready,
                                                                    failed};
};

// ── Capture ─────────────────────────────────────────────────────────────────

Capture *Capture::instance() {
    static auto *capture = new Capture();
    return capture;
}

Capture::Capture() {
    m_display = wl_display_connect(nullptr);
    if (!m_display) {
        qWarning() << "nafeel: no Wayland display for window capture";
        return;
    }
    auto *registry = wl_display_get_registry(m_display);
    wl_registry_add_listener(registry, &CaptureListeners::registry, this);
    wl_display_roundtrip(m_display);
    if (!available() || !m_list) {
        qWarning() << "nafeel: the compositor offers no window capture (ext-image-copy-capture)";
        return;
    }
    ext_foreign_toplevel_list_v1_add_listener(m_list, &CaptureListeners::list, this);
    wl_display_roundtrip(m_display);

    m_notifier = new QSocketNotifier(wl_display_get_fd(m_display), QSocketNotifier::Read, this);
    connect(m_notifier, &QSocketNotifier::activated, this, &Capture::read);
    flush();
}

void Capture::read() {
    while (wl_display_prepare_read(m_display) != 0)
        wl_display_dispatch_pending(m_display);
    if (wl_display_read_events(m_display) < 0 && errno != EAGAIN) {
        qWarning() << "nafeel: lost the window capture connection";
        m_notifier->setEnabled(false);
        return;
    }
    wl_display_dispatch_pending(m_display);
    flush();
}

void Capture::flush() {
    if (m_display)
        wl_display_flush(m_display);
}

void Capture::toplevelDone(Toplevel *t) {
    if (t->id.isEmpty() || m_byId.value(t->id) == t)
        return;
    m_byId.insert(t->id, t);
    emit windowsChanged();
}

void Capture::toplevelClosed(Toplevel *t) {
    if (m_byId.value(t->id) == t)
        m_byId.remove(t->id);
    ext_foreign_toplevel_handle_v1_destroy(t->handle);
    delete t;
    emit windowsChanged();
}

CaptureSession *Capture::session(const QString &windowId, QObject *parent) {
    if (!available())
        return nullptr;
    auto *t = m_byId.value(windowId);
    return t ? new CaptureSession(t->handle, parent) : nullptr;
}

// ── CaptureSession ──────────────────────────────────────────────────────────

CaptureSession::CaptureSession(ext_foreign_toplevel_handle_v1 *handle, QObject *parent) : QObject(parent) {
    auto *c = Capture::instance();
    m_source = ext_foreign_toplevel_image_capture_source_manager_v1_create_source(c->sourceManager(), handle);
    m_session = ext_image_copy_capture_manager_v1_create_session(c->copyManager(), m_source, 0);
    ext_image_copy_capture_session_v1_add_listener(m_session, &CaptureListeners::session, this);
    c->flush();
}

CaptureSession::~CaptureSession() {
    if (m_frame)
        ext_image_copy_capture_frame_v1_destroy(m_frame);
    releaseBuffer();
    if (m_session)
        ext_image_copy_capture_session_v1_destroy(m_session);
    if (m_source)
        ext_image_capture_source_v1_destroy(m_source);
    Capture::instance()->flush();
}

void CaptureSession::request() {
    if (m_stopped || m_frame)
        return;
    m_wanted = true;
    if (m_known)
        start();
}

void CaptureSession::constraintsDone() {
    m_known = m_offerHasFormat && !m_offerSize.isEmpty();
    if (!m_known) {
        stop();
        return;
    }
    if (m_wanted && !m_frame)
        start();
}

void CaptureSession::start() {
    m_wanted = false;
    // New constraints (the window resized): a new buffer.
    if (m_buffer && (m_size != m_offerSize || m_format != m_offerFormat))
        releaseBuffer();
    if (!m_buffer) {
        m_size = m_offerSize;
        m_format = m_offerFormat;
        m_stride = m_size.width() * 4;
        m_bytes = size_t(m_stride) * size_t(m_size.height());
        const int fd = memfd_create("nafeel-thumb", MFD_CLOEXEC);
        if (fd < 0 || ftruncate(fd, off_t(m_bytes)) != 0) {
            if (fd >= 0)
                close(fd);
            stop();
            return;
        }
        void *map = mmap(nullptr, m_bytes, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
        if (map == MAP_FAILED) {
            close(fd);
            stop();
            return;
        }
        m_pixels = static_cast<uchar *>(map);
        auto *pool = wl_shm_create_pool(Capture::instance()->shm(), fd, int32_t(m_bytes));
        m_buffer =
            wl_shm_pool_create_buffer(pool, 0, m_size.width(), m_size.height(), m_stride, m_format);
        wl_shm_pool_destroy(pool);
        close(fd);
        m_fresh = true;
    }

    m_frame = ext_image_copy_capture_session_v1_create_frame(m_session);
    ext_image_copy_capture_frame_v1_add_listener(m_frame, &CaptureListeners::frame, this);
    ext_image_copy_capture_frame_v1_attach_buffer(m_frame, m_buffer);
    // Nothing but the compositor writes to this buffer, so after the first
    // frame it only needs to copy what changed in the window.
    if (m_fresh)
        ext_image_copy_capture_frame_v1_damage_buffer(m_frame, 0, 0, m_size.width(), m_size.height());
    ext_image_copy_capture_frame_v1_capture(m_frame);
    Capture::instance()->flush();
}

void CaptureSession::frameReady() {
    ext_image_copy_capture_frame_v1_destroy(m_frame);
    m_frame = nullptr;
    m_fresh = false;
    emit frame(m_pixels, m_size, m_stride, m_format == WL_SHM_FORMAT_ARGB8888);
}

void CaptureSession::frameFailed(uint32_t reason) {
    ext_image_copy_capture_frame_v1_destroy(m_frame);
    m_frame = nullptr;
    switch (reason) {
    case EXT_IMAGE_COPY_CAPTURE_FRAME_V1_FAILURE_REASON_STOPPED:
        stop();
        break;
    case EXT_IMAGE_COPY_CAPTURE_FRAME_V1_FAILURE_REASON_BUFFER_CONSTRAINTS:
        // New constraints follow (then "done"): ask again with a new buffer.
        releaseBuffer();
        m_wanted = true;
        break;
    default:
        m_fresh = true;
        emit failed();
    }
}

void CaptureSession::stop() {
    if (m_stopped)
        return;
    m_stopped = true;
    m_wanted = false;
    emit stopped();
}

void CaptureSession::releaseBuffer() {
    if (m_buffer) {
        wl_buffer_destroy(m_buffer);
        m_buffer = nullptr;
    }
    if (m_pixels) {
        munmap(m_pixels, m_bytes);
        m_pixels = nullptr;
    }
}
