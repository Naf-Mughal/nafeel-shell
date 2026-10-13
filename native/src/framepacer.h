#pragma once

#include <QAbstractAnimation>
#include <QElapsedTimer>
#include <QList>
#include <QObject>
#include <QPointer>
#include <QQuickWindow>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

class FramePacerDriver;

// Animations advanced once per presented frame (ROADMAP Stage P). Qt's
// threaded render loop locks animations to vsync only while exactly one Qt
// Quick window is visible; the shell always has two (the frame and the
// wallpaper), so Qt drove them from a 16 ms system timer against a 16.65 ms
// display: the two drifted a frame apart every ~400 ms, and a panel's
// close (~300 ms) nearly always showed one frame twice and skipped one.
// This replaces Qt's driver with one that advances at the display's own
// vblanks (the kernel's, waited for on a thread of its own while anything
// animates; asleep otherwise), at each vblank's time: one step per
// refresh, every step the same. (The frame callbacks aren't a clock here:
// umbriel answers them at once while it's idle.) Without a DRM device, a
// precise timer.
//
//   FramePacer.attach(window)   // each frame window, once
class FramePacer : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // Installed: Qt's driver replaced by this one.
    Q_PROPERTY(bool active READ active NOTIFY activeChanged)

public:
    explicit FramePacer(QObject *parent = nullptr);
    ~FramePacer() override;

    bool active() const { return m_driver != nullptr; }

    // Paces animations by this window's presented frames.
    Q_INVOKABLE void attach(QQuickWindow *window);
    // A window whose frames come on their own (the video wallpaper): while
    // animations run, it draws only just after a vblank tick.
    Q_INVOKABLE void attachWallpaper(QQuickWindow *window);
    // With NAFEEL_PRESENT_LOG: a line "M <ns> <what>" in the log (a close
    // starting, for measuring).
    Q_INVOKABLE void mark(const QString &what);

signals:
    void activeChanged();
    // A watched (frame) window was exposed: a configure from the compositor
    // was handled (Qt redraws synchronously for it).
    void exposed();

private:
    bool install();

    FramePacerDriver *m_driver = nullptr;
};
