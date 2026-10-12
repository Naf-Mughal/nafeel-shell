import QtQuick
import qs.config
import qs.services

// A small chip to pick or filter with, on the shell's rounding (like the
// tabs): paper at rest, the secondary container when selected. Optional
// leading icon.
Surface {
    id: root

    property string text
    property string icon
    property bool selected

    role: selected ? "secondary" : "paper"
    level: 3
    radius: pressed ? Tokens.rounding.small : Tokens.rounding.morph
    interactive: true
    pressDepth: 0.94
    implicitHeight: 32
    implicitWidth: row.implicitWidth + Tokens.spacing.large * 2

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        MaterialIcon {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            fill: root.selected ? 1 : 0
            color: root.ink
            size: 16
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.selected ? root.ink : root.subInk
            font.pixelSize: Tokens.font.small
            font.weight: root.selected ? Font.DemiBold : Font.Normal
        }
    }
}
