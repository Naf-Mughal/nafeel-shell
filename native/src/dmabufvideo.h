#pragma once

#include <QPointer>
#include <QQuickItem>
#include <QQuickWindow>
#include <QtQml/qqmlregistration.h>

#include <memory>

class DmabufVideoWorker;

// A live wallpaper that never goes through the scene (ROADMAP Stage P/O):
// ffmpeg decodes on the GPU (VAAPI), the video processor scales each frame
// to cover the item and converts it to RGB (BT.709, its own matrix: umbriel
// has no colour-representation protocol to tell it), and the frame goes to
// the compositor as it is, a dmabuf on a subsurface under the item's window.
// Nothing is drawn in the shell: no GL pass, no scene sync, no render-thread
// wake per frame. Frames are committed on the display's refresh grid
// (FramePacer::lastVblank) at a fixed point of the refresh before their own,
// one every k refreshes when the rate divides the refresh (the clip played
// a hair faster or slower to fit, as MpvVideo does), so its loop point
// doesn't break the cadence either.
//
// The subsurface sits below the window's own surface: the window must be
// clear over the item while `ready` (the still under it hidden, no
// background colour), and anything the window draws (the ink of a change)
// stays on top. Same interface as MpvVideo; `broken` when it can't (no
// VAAPI, no dmabuf), for the caller to fall back to MpvVideo.
//
//   DmabufVideo { anchors.fill: parent; source: "file:///…"; playing: true }
class DmabufVideo : public QQuickItem {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(bool playing READ playing WRITE setPlaying NOTIFY playingChanged)
    // Where to start, in ms, once the file has loaded (a handover).
    Q_PROPERTY(int startAt READ startAt WRITE setStartAt NOTIFY startAtChanged)
    // Where it is, in ms (read when asked).
    Q_PROPERTY(int position READ position NOTIFY positionChanged)
    // A frame is on screen.
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)

public:
    explicit DmabufVideo(QQuickItem *parent = nullptr);
    ~DmabufVideo() override;

    QString source() const { return m_source; }
    void setSource(const QString &source);
    bool playing() const { return m_playing; }
    void setPlaying(bool playing);
    int startAt() const { return m_startAt; }
    void setStartAt(int ms);
    int position() const;
    bool ready() const { return m_ready; }

signals:
    void sourceChanged();
    void playingChanged();
    void startAtChanged();
    void positionChanged();
    void readyChanged();
    void firstFrame();
    void broken();

protected:
    void itemChange(ItemChange change, const ItemChangeData &data) override;
    void geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry) override;

private slots:
    void onFirstFrame();
    void onBroken();
    void attachWindow();

private:
    void push();

    std::unique_ptr<DmabufVideoWorker> m_worker;
    QPointer<QQuickWindow> m_window;
    QString m_source;
    bool m_playing = true;
    int m_startAt = 0;
    bool m_ready = false;
    bool m_haveParent = false;
};
