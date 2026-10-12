import QtQuick
import qs.config
import qs.services

// A round Material icon button (a Surface). `filled` uses the colour pair as
// a solid fill; otherwise it's a tonal button on the paper. A `caption` (a
// level, say) sits small under the icon.
Surface {
    id: root

    property string icon
    property bool filled: false
    property color fillColour: Colours.palette.m3secondaryContainer
    property color inkColour: Colours.palette.m3onSecondaryContainer
    property int size: 40
    property string caption: ""

    interactive: true
    pressDepth: 0.9
    implicitWidth: size
    implicitHeight: size
    color: filled ? fillColour : Colours.roleFill("paper", "soft", 3)
    ink: filled ? inkColour : Colours.palette.m3onSurface
    // M3 Expressive shape morph: rounder at rest, squarer while pressed.
    radius: pressed ? Tokens.rounding.small : Math.min(size / 2, Tokens.rounding.morph)

    Column {
        anchors.centerIn: parent
        spacing: -2

        MaterialIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.icon
            fill: root.filled ? 1 : 0
            color: root.ink
            size: Math.round(root.size * (root.caption ? 0.4 : 0.5))
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.caption !== ""
            text: root.caption
            color: root.ink
            font.family: Tokens.font.mono
            font.pixelSize: Math.round(root.size * 0.25)
            font.weight: Font.DemiBold
        }
    }
}
