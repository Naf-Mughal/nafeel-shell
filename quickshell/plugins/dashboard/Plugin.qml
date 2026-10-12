import QtQuick
import Quickshell

// The dashboard plugin's root: it touches the visualiser so its settings
// (the Media page) are there from the start; the visualiser itself only
// listens while the Media tab shows it. The dashboard is the manifest's
// drawer.
Scope {
    readonly property var visualiser: Visualiser
}
