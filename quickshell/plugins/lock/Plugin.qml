import QtQuick
import Quickshell

// The lock plugin's root: the lock screen (cave abode; IPC `lock …`), its
// look and settings (CaveAbode: the Session & lock page, the lock before
// sleep), the cultivation it keeps (LockStats) and what the login screen
// shows (GreeterExport). Its singletons are made here so they run from the
// start. Off: the shell can't lock (shell-msg lock falls back to cave-abode's
// standalone lock screen).
Scope {
    readonly property var look: CaveAbode
    readonly property var stats: LockStats
    readonly property var greeter: GreeterExport

    Lock {}
}
