import QtQuick
import qs.config
import qs.services

// "Nothing here", said properly: a soft ink-wash disc with the icon, a serif
// title, a one-line hint, and an optional action.
Column {
    id: root

    property string icon
    property string title
    property string hint
    property string actionText
    signal action

    spacing: Tokens.spacing.small
    topPadding: Tokens.spacing.huge
    bottomPadding: Tokens.spacing.huge

    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 72
        height: 72

        // Ink wash: two soft, offset discs of the accent, barely there.
        Rectangle {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: -5
            width: 64
            height: 64
            radius: 32
            color: Qt.alpha(Colours.palette.m3primary, 0.08)
        }
        Rectangle {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: 6
            anchors.verticalCenterOffset: 3
            width: 52
            height: 52
            radius: 26
            color: Qt.alpha(Colours.palette.m3tertiary, 0.08)
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: root.icon
            size: 30
            color: Colours.palette.m3onSurfaceVariant
        }
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.title
        font.family: Tokens.font.serif
        font.pixelSize: Tokens.font.value
        color: Colours.palette.m3onSurface
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(implicitWidth, root.width - Tokens.spacing.huge)
        visible: text !== ""
        text: root.hint
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        color: Colours.palette.m3onSurfaceVariant
        font.pixelSize: Tokens.font.small
    }

    Item {
        width: 1
        height: Tokens.spacing.small
        visible: root.actionText !== ""
    }

    StyledRect {
        id: button

        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.actionText !== ""
        width: label.implicitWidth + Tokens.spacing.huge * 2
        height: 36
        radius: Tokens.rounding.small
        color: Colours.palette.m3secondaryContainer

        StateLayer {
            hovered: hover.hovered
            pressed: tap.pressed
            ink: Colours.palette.m3onSecondaryContainer
        }

        StyledText {
            id: label

            anchors.centerIn: parent
            text: root.actionText
            color: Colours.palette.m3onSecondaryContainer
            font.pixelSize: Tokens.font.body
            font.weight: Font.DemiBold
        }

        HoverHandler {
            id: hover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            id: tap

            onTapped: root.action()
        }
    }
}
