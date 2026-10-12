pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import M3Shapes
import qs.config
import qs.services
import qs.components

// A labelled reading on one line (the network's).
Item {
    id: reading

    property string icon
    property string label
    property string value
    property string role
    property color dim: Colours.roleSubInk("paper", "soft")
    readonly property color tone: role === "paper" ? dim : Colours.roleInk(role, "ghost")

    Layout.fillWidth: true
    implicitHeight: 24

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spacing.small

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: reading.icon
            size: 18
            color: reading.tone
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: reading.label
            color: reading.dim
            font.pixelSize: Tokens.font.small
        }
    }

    StyledText {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: reading.value
        color: reading.tone
        font.pixelSize: reading.role === "paper" ? Tokens.font.small : Tokens.font.row
        font.weight: Font.Medium
    }
}
