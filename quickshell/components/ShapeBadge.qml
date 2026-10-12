import QtQuick
import M3Shapes
import qs.config
import qs.services

// An icon on a Material 3 shape in a role (Caelestia's badges: the gem logo,
// the clamshell uptime, the cookie usage). Morphs when `shape` changes.
//
//   ShapeBadge { shape: MaterialShape.ClamShell; role: "tertiary"; icon: "schedule" }
MaterialShape {
    id: root

    property string role: "primary"
    property string emphasis: "soft"
    property string icon
    property real iconSize: implicitSize * 0.42
    readonly property color ink: Colours.roleInk(role, emphasis)

    implicitSize: 48
    color: Colours.roleFill(role, emphasis, 0)

    MaterialIcon {
        visible: root.icon !== ""
        anchors.centerIn: parent
        text: root.icon
        size: root.iconSize
        color: root.ink
        fill: 1
    }
}
