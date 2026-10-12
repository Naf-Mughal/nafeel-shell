pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.lock
import qs.modules.lock.themes.xianxia
import qs.services as Services

// Cave Abode lock screen, started by the plugin (bin/cave-abode-lock).
//
// Grabs every screen first so the formation can draw itself over the desktop,
// then takes the session lock. When PAM accepts the password and the reward
// and outro have played, LockContext emits `released`: drop the lock and
// quit. Locking never waits more than ~450 ms for the capture.
ShellRoot {
    id: root

    property bool engaged: false
    property bool releasing: false

    function engage() {
        if (engaged)
            return;
        engaged = true;
        lockCtx.configure(Services.CaveAbode.timing);
        lockCtx.begin();
        sessionLock.locked = true;
    }

    function release() {
        if (releasing)
            return;
        releasing = true;
        sessionLock.locked = false;
        quitTimer.start();
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
        id: quitTimer
        interval: 150
        onTriggered: Qt.quit()
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
                console.warn("lock: session lock refused or ended by the compositor, exiting");
                Qt.exit(2);
            }
        }

        WlSessionLockSurface {
            id: lockSurface
            color: "black"

            XianxiaSurface {
                anchors.fill: parent
                ctx: lockCtx
                shot: capture.urlFor(lockSurface.screen)
                shown: lockSurface.visible
            }
        }
    }
}
