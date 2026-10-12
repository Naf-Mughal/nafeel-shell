import QtQuick
import Quickshell

// The capture plugin's root: screenshots and screen recordings (Capture:
// its IPC `capture …`, its settings page), the region picker and the
// annotator. The bar's capture button and the lock's capture tokens reach
// it through Plugins.instance("capture").capture and go when it's off.
Scope {
    id: root

    readonly property Capture capture: Capture {}

    Picker {
        capture: root.capture
    }

    Annotator {
        capture: root.capture
    }
}
