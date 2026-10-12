#pragma once

#include <QElapsedTimer>
#include <QImage>
#include <QPointer>
#include <QQuickItem>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

class CaptureSession;

// A picture of one window, by umbriel window id. It captures only while it's
// visible on a visible surface, takes a new frame only when the window has
// changed (at most `fps` a second), and keeps the pixels at the size it's
// drawn at, so a thumbnail costs a thumbnail's memory. The last frame stays
// up when capture stops (hidden, or the window closed).
class WindowThumb : public QQuickItem {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString windowId READ windowId WRITE setWindowId NOTIFY windowIdChanged)
    // Keep following the window (otherwise one frame per showing).
    Q_PROPERTY(bool live READ live WRITE setLive NOTIFY liveChanged)
    Q_PROPERTY(int fps READ fps WRITE setFps NOTIFY fpsChanged)
    // Fill the item and crop the overflow, rather than fit inside it.
    Q_PROPERTY(bool crop READ crop WRITE setCrop NOTIFY cropChanged)
    // A frame has arrived.
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)
    // The window's size in pixels (from its last frame).
    Q_PROPERTY(QSize sourceSize READ sourceSize NOTIFY sourceSizeChanged)
    // Where the picture is drawn inside the item (for fit).
    Q_PROPERTY(QRectF paintedRect READ paintedRect NOTIFY paintedRectChanged)

public:
    explicit WindowThumb(QQuickItem *parent = nullptr);
    ~WindowThumb() override;

    QString windowId() const { return m_windowId; }
    void setWindowId(const QString &id);
    bool live() const { return m_live; }
    void setLive(bool live);
    int fps() const { return m_fps; }
    void setFps(int fps);
    bool crop() const { return m_crop; }
    void setCrop(bool crop);
    bool ready() const { return !m_image.isNull(); }
    QSize sourceSize() const { return m_sourceSize; }
    QRectF paintedRect() const;

signals:
    void windowIdChanged();
    void liveChanged();
    void fpsChanged();
    void cropChanged();
    void readyChanged();
    void sourceSizeChanged();
    void paintedRectChanged();

protected:
    QSGNode *updatePaintNode(QSGNode *old, UpdatePaintNodeData *) override;
    void itemChange(ItemChange change, const ItemChangeData &data) override;
    void geometryChange(const QRectF &now, const QRectF &before) override;

private:
    bool wanted() const;
    void sync();
    void dropSession();
    void onFrame(const uchar *pixels, QSize size, int stride, bool alpha);
    void requestNext();

    QString m_windowId;
    bool m_live = true;
    int m_fps = 30;
    bool m_crop = false;

    QPointer<CaptureSession> m_session;
    QTimer m_pace;  // holds the next request back to the frame rate
    QTimer m_retry; // after a passing failure
    QElapsedTimer m_since;
    bool m_shown = false; // this showing has its frame (for !live)

    QImage m_image;
    bool m_textureDirty = false;
    QSize m_sourceSize;
    QMetaObject::Connection m_windowVisible;
};
