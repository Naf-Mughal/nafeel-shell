#pragma once

#include <QQuickFramebufferObject>
#include <QtQml/qqmlregistration.h>
#include <memory>

struct mpv_handle;

// A video drawn by libmpv inside the scene (ROADMAP Stage P): mpv decodes on
// the GPU (VAAPI) and its render API draws the frame straight into this
// item's framebuffer, scaled to its size, without the frame ever going
// through the CPU (Qt Multimedia's path cost ~20% of the GPU for a 4K
// wallpaper). No window of its own, so no idle inhibitor (mpvpaper's kept
// the session from going idle), and it works wherever an item does: the
// desktop and the lock screen. Looped and silent; it covers the item (crop).
//
//   MpvVideo { source: "file:///…"; playing: true; onFirstFrame: … }
class MpvVideo : public QQuickFramebufferObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(bool playing READ playing WRITE setPlaying NOTIFY playingChanged)
    // Where to start, in ms, once the file has loaded (a handover).
    Q_PROPERTY(int startAt READ startAt WRITE setStartAt NOTIFY startAtChanged)
    // Where it is, in ms (asked of mpv when read: not followed, which woke
    // the GUI thread 30 times a second for nothing).
    Q_PROPERTY(int position READ position NOTIFY positionChanged)
    // A frame has been drawn.
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)

public:
    explicit MpvVideo(QQuickItem *parent = nullptr);
    ~MpvVideo() override;

    Renderer *createRenderer() const override;

    QString source() const { return m_source; }
    void setSource(const QString &source);
    bool playing() const { return m_playing; }
    void setPlaying(bool playing);
    int startAt() const { return m_startAt; }
    void setStartAt(int ms);
    int position() const;
    bool ready() const { return m_ready; }

    // For the renderer (render thread): the shared handle.
    std::shared_ptr<mpv_handle> handle() const { return m_mpv; }

signals:
    void sourceChanged();
    void playingChanged();
    void startAtChanged();
    void positionChanged();
    void readyChanged();
    void firstFrame();
    void broken();

public slots:
    // From the renderer, once a frame has been drawn.
    void frameDrawn();
    // From the renderer: its render context exists, so a file can load (mpv
    // needs its video output, the render context, before it opens one).
    void contextReady();

private slots:
    void onEvents();

private:
    void load();

    std::shared_ptr<mpv_handle> m_mpv;
    QString m_source;
    bool m_playing = true;
    int m_startAt = 0;
    int m_position = 0;
    bool m_ready = false;
    bool m_context = false;
};
