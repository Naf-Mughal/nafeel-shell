#pragma once

#include <QMutex>
#include <QQuickItem>
#include <QThread>
#include <QWaitCondition>
#include <QtQml/qqmlregistration.h>

#include <atomic>

struct AVFrame;
class SceneVideoWorker;

// A video drawn in the scene from the GPU's own frames, for where it's a
// texture under other drawing (the lock screen's backdrop): ffmpeg decodes
// on the GPU (VAAPI), the video processor scales each frame once to the
// size it's drawn at (`resolution` of the item's pixels: the lock paints it
// at half) and converts it to RGB, and the frame becomes a GL texture as it
// is (its dmabuf, an EGLImage; one per pool surface, made once). No libmpv,
// no render pass of its own: MpvVideo for the same cost ~40 MB of memory,
// ~75 MB of video memory and a full-size render each frame.
//
// Same interface as MpvVideo (source, playing, ready, firstFrame, frame,
// broken: no VAAPI or dmabuf import, for the caller to fall back to it).
// Played at the file's own rate, looped, silent; it covers the item (crop).
class SceneVideo : public QQuickItem {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(bool playing READ playing WRITE setPlaying NOTIFY playingChanged)
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)
    // Of the item's size in pixels, what the frames are scaled to (0.5: half).
    Q_PROPERTY(qreal resolution READ resolution WRITE setResolution NOTIFY resolutionChanged)

public:
    explicit SceneVideo(QQuickItem *parent = nullptr);
    ~SceneVideo() override;

    QString source() const { return m_source; }
    void setSource(const QString &source);
    bool playing() const { return m_playing; }
    void setPlaying(bool playing);
    bool ready() const { return m_ready; }
    qreal resolution() const { return m_resolution; }
    void setResolution(qreal r);

    // From the worker (GUI thread): the frame to show now (owned here).
    Q_INVOKABLE void takeFrame(void *frame);
    Q_INVOKABLE void onBroken();

signals:
    void sourceChanged();
    void playingChanged();
    void readyChanged();
    void resolutionChanged();
    void firstFrame();
    // A new frame goes into the next scene frame (as MpvVideo.frame).
    void frame();
    void broken();

protected:
    QSGNode *updatePaintNode(QSGNode *old, UpdatePaintNodeData *) override;
    void geometryChange(const QRectF &n, const QRectF &o) override;
    void itemChange(ItemChange change, const ItemChangeData &data) override;

private:
    void push();

    SceneVideoWorker *m_worker = nullptr;
    QString m_source;
    bool m_playing = true;
    bool m_ready = false;
    qreal m_resolution = 1;
    // The newest frame, not yet in the scene (GUI thread).
    AVFrame *m_next = nullptr;
};
