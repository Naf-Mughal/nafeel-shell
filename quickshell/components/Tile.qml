import QtQuick
import qs.config
import qs.services

// An M3 Expressive toggle tile (a Surface): icon, label and state line. On,
// it fills with primary and its corners round out further (a shape change,
// not just a colour one).
Surface {
    id: root

    property string icon
    property string label
    property string sublabel
    property bool checked
    // Icon above the label, centred: for tiles three or more across.
    property bool stacked: false

    role: checked ? "primary" : "paper"
    emphasis: "strong"
    level: 3
    interactive: true
    pressDepth: 0.97
    implicitHeight: 64
    radius: checked ? Tokens.rounding.large : pressed ? Tokens.rounding.small : Tokens.rounding.normal

    Column {
        visible: root.stacked
        anchors.centerIn: parent
        spacing: 2

        MaterialIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.icon
            fill: root.checked ? 1 : 0
            color: root.ink
            size: 22
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            color: root.ink
            font.pixelSize: Tokens.font.small
            font.weight: Font.DemiBold
        }
    }

    Row {
        visible: !root.stacked
        anchors.left: parent.left
        anchors.leftMargin: Tokens.spacing.large
        anchors.right: parent.right
        anchors.rightMargin: Tokens.spacing.normal
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spacing.normal

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            fill: root.checked ? 1 : 0
            color: root.ink
            size: 22
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 22 - Tokens.spacing.normal

            StyledText {
                width: parent.width
                text: root.label
                color: root.ink
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                visible: text !== ""
                text: root.sublabel
                color: root.subInk
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }
    }
}
