pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// The lock screen, in the shell's own process: Cave Abode's xianxia lock,
// created for each lock and freed after unlock.
//
//   qs -p <shell> ipc call lock lock        lock now (no-op while locked)
//   qs -p <shell> ipc call lock isLocked
//
// Cave Abode's bin/cave-abode-lock (keybinds, session menu, idle, before
// suspend) calls this when the shell runs, and falls back to its own
// standalone lock when it doesn't. If the shell dies while locked, the
// compositor keeps the screen locked and the marker file makes the restarted
// shell lock again straight away.
Scope {
    id: root

    readonly property string marker: Quickshell.env("XDG_RUNTIME_DIR") + "/nafeel-shell-locked"
    readonly property bool locked: session.active

    onLockedChanged: ShellState.locked = locked

    function lock(): void {
        if (session.active)
            return;
        ShellState.close();
        markerFile.setText(String(Date.now()));
        session.active = true;
    }

    function done(unlocked: bool): void {
        session.active = false;
        Quickshell.execDetached(["rm", "-f", root.marker]);
    }

    LazyLoader {
        id: session

        LockSession {
            onFinished: unlocked => root.done(unlocked)
        }
    }

    // Locked when the shell last stopped: lock again.
    FileView {
        id: markerFile

        path: root.marker
        printErrors: false
        blockLoading: true
        Component.onCompleted: {
            if (text() !== "") {
                console.warn("lock: the shell stopped while locked; locking again");
                root.lock();
            }
        }
    }

    Connections {
        target: Session

        function onLockRequested(): void {
            root.lock();
        }
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock();
        }

        function isLocked(): bool {
            return root.locked;
        }
    }
}
