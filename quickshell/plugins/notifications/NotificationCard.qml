pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.config
import qs.services
import qs.components

// One notification: image (or app icon), app and time, summary, body, its
// buttons and a close button. Clicking the text runs its default action.
StyledRect {
    id: root

    required property var entry
    // Toasts close the popup; history removes the notification.
    property bool toast: false

    function ago(ms: real): string {
        const s = Math.max(0, (Date.now() - ms) / 1000);
        if (s < 60)
            return "now";
        if (s < 3600)
            return `${Math.floor(s / 60)} min`;
        if (s < 86400)
            return `${Math.floor(s / 3600)} h`;
        return `${Math.floor(s / 86400)} d`;
    }

    readonly property bool critical: entry.urgency === NotificationUrgency.Critical

    implicitHeight: content.implicitHeight + Tokens.spacing.normal * 2
    radius: Tokens.rounding.large
    color: critical ? Colours.palette.m3errorContainer : toast ? Colours.palette.m3surfaceContainer : Colours.palette.m3surfaceContainerHigh

    Column {
        id: content

        x: Tokens.spacing.normal
        y: Tokens.spacing.normal
        width: parent.width - Tokens.spacing.normal * 2
        spacing: Tokens.spacing.small

        Row {
            width: parent.width
            spacing: Tokens.spacing.normal

            ClippingRectangle {
                id: picture

                width: 44
                height: 44
                radius: Tokens.rounding.small
                color: Colours.palette.m3secondaryContainer

                Image {
                    anchors.fill: parent
                    visible: root.entry.image !== ""
                    source: root.entry.image
                    sourceSize: Qt.size(88, 88)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                IconImage {
                    anchors.centerIn: parent
                    visible: root.entry.image === "" && root.entry.icon !== ""
                    implicitSize: 28
                    source: root.entry.icon ? (root.entry.icon.startsWith("/") ? "file://" + root.entry.icon : Quickshell.iconPath(root.entry.icon, "dialog-information")) : ""
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: root.entry.image === "" && root.entry.icon === ""
                    text: root.critical ? "priority_high" : "notifications"
                    fill: 1
                    color: Colours.palette.m3onSecondaryContainer
                }
            }

            // Clicking the text runs the default action.
            Column {
                width: parent.width - picture.width - close.width - Tokens.spacing.normal * 2

                TapHandler {
                    onTapped: Notifs.invoke(root.entry, "default")
                }

                Row {
                    width: parent.width
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: root.entry.app
                        color: root.critical ? Colours.palette.m3onErrorContainer : Colours.palette.m3primary
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }

                    StyledText {
                        text: "· " + root.ago(root.entry.time)
                        color: Colours.palette.m3onSurfaceVariant
                        font.pixelSize: 11
                    }
                }

                StyledText {
                    width: parent.width
                    text: root.entry.summary
                    color: root.critical ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSurface
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width
                    visible: text !== ""
                    text: root.entry.body
                    color: root.critical ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSurfaceVariant
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                    maximumLineCount: root.toast ? 4 : 3
                    elide: Text.ElideRight
                    textFormat: Text.StyledText
                    onLinkActivated: link => Qt.openUrlExternally(link)
                }
            }

            IconButton {
                id: close

                icon: "close"
                size: 28
                onClicked: root.toast ? Notifs.hidePopup(root.entry) : Notifs.remove(root.entry)
            }
        }

        Row {
            visible: root.entry.actions.length > 0
            x: picture.width + Tokens.spacing.normal
            spacing: Tokens.spacing.small

            Repeater {
                model: root.entry.actions

                StyledRect {
                    id: button

                    required property var modelData

                    width: label.implicitWidth + Tokens.spacing.large * 2
                    height: 30
                    radius: Tokens.rounding.small
                    color: Colours.palette.m3secondaryContainer

                    StateLayer {
                        hovered: hover.hovered
                        pressed: actTap.pressed
                        ink: Colours.palette.m3onSecondaryContainer
                    }

                    StyledText {
                        id: label

                        anchors.centerIn: parent
                        text: button.modelData.text
                        color: Colours.palette.m3onSecondaryContainer
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    HoverHandler {
                        id: hover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        id: actTap

                        onTapped: Notifs.invoke(root.entry, button.modelData.identifier)
                    }
                }
            }
        }
    }
}
