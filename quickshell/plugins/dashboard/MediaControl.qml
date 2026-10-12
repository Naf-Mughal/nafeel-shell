import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// A media control: a Surface with an icon, all of them the same height and
// on the shell's rounding (so they follow the radius setting). `on` fills it
// in the primary role (playing, shuffle on, repeat on).
Surface {
    id: root

    property string icon
    property bool on: false
    property int iconSize: 22

    implicitWidth: 52
    implicitHeight: 52
    Layout.preferredHeight: 52
    role: on ? "primary" : "secondary"
    emphasis: on ? "strong" : "soft"
    interactive: enabled
    opacity: enabled ? 1 : 0.4

    MaterialIcon {
        anchors.centerIn: parent
        text: root.icon
        fill: root.on ? 1 : 0
        size: root.iconSize
        color: root.ink
    }
}
