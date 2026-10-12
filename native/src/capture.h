#pragma once

#include <QHash>
#include <QObject>
#include <QSize>

struct wl_buffer;
struct wl_display;
struct wl_shm;
struct ext_foreign_toplevel_list_v1;
struct ext_foreign_toplevel_handle_v1;
struct ext_image_copy_capture_manager_v1;
struct ext_image_copy_capture_session_v1;
struct ext_image_copy_capture_frame_v1;
struct ext_foreign_toplevel_image_capture_source_manager_v1;
struct ext_image_capture_source_v1;
class QSocketNotifier;

// One window's pixels, a frame at a time. The buffer stays across frames, so
// after the first one the compositor copies only what changed, and it holds a
// frame back until the window has changed at all.
class CaptureSession : public QObject {
    Q_OBJECT

public:
    CaptureSession(ext_foreign_toplevel_handle_v1 *handle, QObject *parent);
    ~CaptureSession() override;

    // Ask for the next frame (one at a time; ignored while one is pending).
    void request();
    bool pending() const { return m_frame != nullptr || m_wanted; }

signals:
    // The pixels (BGRx or premultiplied BGRA: QImage::Format_RGB32 or _ARGB32_Premultiplied) are only valid during the
    // signal.
    void frame(const uchar *pixels, QSize size, int stride, bool alpha);
    // A frame failed for no lasting reason; ask again later.
    void failed();
    // The window is gone (or can't be captured); this session is done.
    void stopped();

private:
    friend struct CaptureListeners;

    void constraintsDone();
    void start();
    void frameReady();
    void frameFailed(uint32_t reason);
    void stop();
    void releaseBuffer();

    ext_image_capture_source_v1 *m_source = nullptr;
    ext_image_copy_capture_session_v1 *m_session = nullptr;
    ext_image_copy_capture_frame_v1 *m_frame = nullptr;

    // The constraints as the compositor last sent them, and the buffer made
    // for them.
    QSize m_offerSize;
    uint32_t m_offerFormat = 0;
    bool m_offerHasFormat = false;
    bool m_known = false;

    QSize m_size;
    uint32_t m_format = 0;
    int m_stride = 0;
    wl_buffer *m_buffer = nullptr;
    uchar *m_pixels = nullptr;
    size_t m_bytes = 0;
    bool m_fresh = true; // the buffer has never been filled: damage it all

    bool m_wanted = false;
    bool m_stopped = false;
};

// The compositor connection (its own, so it never waits on Qt's) and the
// window list it offers, by umbriel window id.
class Capture : public QObject {
    Q_OBJECT

public:
    static Capture *instance();

    bool available() const { return m_copyManager && m_sourceManager && m_shm; }
    // A new session for a window, or null if there's no such window (yet).
    CaptureSession *session(const QString &windowId, QObject *parent);
    void flush();

    wl_shm *shm() const { return m_shm; }
    ext_image_copy_capture_manager_v1 *copyManager() const { return m_copyManager; }
    ext_foreign_toplevel_image_capture_source_manager_v1 *sourceManager() const { return m_sourceManager; }

signals:
    // Windows came or went: a thumb waiting for its window can look again.
    void windowsChanged();

private:
    friend struct CaptureListeners;

    struct Toplevel {
        Capture *owner = nullptr;
        ext_foreign_toplevel_handle_v1 *handle = nullptr;
        QString id;
    };

    Capture();
    void read();
    void toplevelDone(Toplevel *t);
    void toplevelClosed(Toplevel *t);

    wl_display *m_display = nullptr;
    QSocketNotifier *m_notifier = nullptr;
    wl_shm *m_shm = nullptr;
    ext_foreign_toplevel_list_v1 *m_list = nullptr;
    ext_image_copy_capture_manager_v1 *m_copyManager = nullptr;
    ext_foreign_toplevel_image_capture_source_manager_v1 *m_sourceManager = nullptr;
    QHash<QString, Toplevel *> m_byId;
};
