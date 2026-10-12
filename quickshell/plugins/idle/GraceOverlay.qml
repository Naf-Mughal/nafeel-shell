pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// The pre-action fade (Noctalia's idle grace overlay): every screen sinks
// into ink over the profile's fade seconds before an idle action; any input
// cancels it (the idle monitors resume) and it lifts at once. It takes no
// input itself, so moving the mouse reaches the compositor.
Variants {
    id: overlay

    // The idle manager (the plugin's).
    required property var idle

    model: idle.fading ? Quickshell.screens : []

    PanelWindow {
        id: win

        required property ShellScreen modelData

        screen: modelData
        anchors {
            left: true
            right: true
            top: true
            bottom: true
        }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "nafeel-idle-fade"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}

        Rectangle {
            id: ink

            anchors.fill: parent
            color: "black"
            opacity: 0

            NumberAnimation on opacity {
                from: 0
                to: 0.92
                duration: Math.max(1, overlay.idle.fade * 1000)
                easing.type: Easing.InQuad
                running: true
            }
        }
    }
}
