import QtQuick
import Quickshell

// The window switcher plugin's root (Alt+Tab): the Switcher (its IPC
// `switcher …`, the MRU list), made here so Alt+Tab works from the start.
// The carousel is the manifest's drawer, the keys its frame overlay (they
// work before the carousel shows: a quick tap never shows it).
Scope {
    readonly property var switcher: Switcher
    readonly property bool shown: Switcher.shown
}
