import QtQuick
import Quickshell

// The notifications plugin's root: the shell's notification server (Notifs:
// history, toasts, do not disturb; its settings page), made here so it holds
// the D-Bus name from the start. Its drawers (the toasts, the action center)
// are the manifest's. Outside the plugin, Notifs is reached as
// Plugins.instance("notifications").notifs, so nothing starts the server
// while the plugin is off.
Scope {
    readonly property var notifs: Notifs
    readonly property bool hasPopups: Notifs.popups.length > 0
}
