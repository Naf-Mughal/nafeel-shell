import QtQuick
import M3Shapes
import qs.config
import qs.services

// An icon on a Material 3 shape in a role (Caelestia's badges: the gem logo,
// the clamshell uptime, the cookie usage). Morphs when `shape` changes.
// `live` (media playing, say): it breathes, slowly, only while shown.
//
//   ShapeBadge { shape: MaterialShape.ClamShell; role: "tertiary"; icon: "schedule" }
MaterialShape {
    id: root

    property string role: "primary"
    property string emphasis: "soft"
    property string icon
    property real iconSize: implicitSize * 0.42
    property bool live: false
    readonly property color ink: Colours.roleInk(role, emphasis)

    implicitSize: 48
    color: Colours.roleFill(role, emphasis, 0)

    SequentialAnimation on scale {
        running: root.live && root.visible && !Tokens.reduceMotion
        loops: Animation.Infinite
        onRunningChanged: if (!running)
            root.scale = 1

        NumberAnimation {
            to: 1.045
            duration: 1600
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            to: 1
            duration: 1600
            easing.type: Easing.InOutSine
        }
    }

    MaterialIcon {
        visible: root.icon !== ""
        anchors.centerIn: parent
        text: root.icon
        size: root.iconSize
        color: root.ink
        fill: 1
    }
}
