pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.plugins.lock.themes.xianxia
import qs.services as Services

// One lock, from Cave Abode's Lock.qml (nafeel/cave-abode), run inside the
// shell: grab every screen so the formation can draw itself over the desktop,
// take the session lock, and when PAM accepts and the reward and outro have
// played, drop it and report `finished`. Locking never waits more than
// ~450 ms for the capture.
Scope {
    id: root

    property bool engaged: false
    property bool releasing: false

    // unlocked: true after a normal unlock, false if the compositor refused
    // or ended the lock.
    signal finished(bool unlocked)

    function engage(): void {
        if (engaged)
            return;
        engaged = true;
        lockCtx.configure(CaveAbode.timing);
        lockCtx.begin();
        sessionLock.locked = true;
    }

    function release(): void {
        if (releasing)
            return;
        releasing = true;
        sessionLock.locked = false;
        doneTimer.start();
    }

    ScreenCapture {
        id: capture

        onFinished: root.engage()
    }

    Timer {
        interval: 450
        running: true
        onTriggered: root.engage()
    }

    Timer {
        id: doneTimer

        interval: 150
        onTriggered: root.finished(true)
    }

    // What the surface needs from the shell (palette, wallpaper, stats…).
    ShellLockHost {
        id: lockHost
    }

    LockContext {
        id: lockCtx

        onReleased: root.release()
    }

    WlSessionLock {
        id: sessionLock

        // False once the compositor refuses the lock (another locker holds
        // it) or ends it: nothing left to guard.
        onSecureChanged: {
            if (!secure && root.engaged && !root.releasing) {
                console.warn("lock: session lock refused or ended by the compositor");
                root.finished(false);
            }
        }

        WlSessionLockSurface {
            id: lockSurface

            color: "black"

            XianxiaSurface {
                anchors.fill: parent
                ctx: lockCtx
                host: lockHost
                shot: capture.urlFor(lockSurface.screen)
                shown: lockSurface.visible
            }

            // The desktop's frame, kept round the lock.
            LockFrame {
                anchors.fill: parent
            }
        }
    }
}
