import QtQuick
import Quickshell

// The notes plugin's root, made while it's on (Plugins.instance("notes")):
// it owns the store (its files, its IPC `notes jot|create`, its settings
// page), so a jot works without the drawer ever opening, and everything goes
// when the plugin is switched off. The drawer is the manifest's.
Scope {
    readonly property NotesStore store: NotesStore {}
}
