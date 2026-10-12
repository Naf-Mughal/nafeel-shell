import QtQuick
import qs.config
import qs.services

// A list row (a Surface, no fill until highlighted): leading icon, title and
// subtitle, trailing items.
Surface {
    id: root

    property string icon
    property real iconFill: 0
    property string title
    property string subtitle
    property bool highlighted
    default property alias trailing: end.data

    role: highlighted ? "secondary" : "paper"
    emphasis: highlighted ? "soft" : "ghost"
    interactive: true
    pressDepth: 1
    morph: false
    implicitHeight: 52

    MaterialIcon {
        id: lead

        anchors.left: parent.left
        anchors.leftMargin: Tokens.spacing.normal
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        fill: root.iconFill
        color: root.highlighted ? root.ink : root.subInk
    }

    Column {
        anchors.left: lead.right
        anchors.leftMargin: Tokens.spacing.normal
        anchors.right: end.left
        anchors.rightMargin: Tokens.spacing.small
        anchors.verticalCenter: parent.verticalCenter

        StyledText {
            width: parent.width
            text: root.title
            color: root.ink
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        StyledText {
            width: parent.width
            visible: text !== ""
            text: root.subtitle
            color: root.subInk
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }

    Row {
        id: end

        anchors.right: parent.right
        anchors.rightMargin: Tokens.spacing.small
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spacing.small
    }
}
