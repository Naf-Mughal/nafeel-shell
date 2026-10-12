import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// You: the wallpaper behind, your face (~/.face) or initial seal, name,
// user@host and how long the machine has been up.
Surface {
    id: root

    level: 2

    ClippingRectangle {
        anchors.fill: parent
        radius: root.restRadius
        color: "transparent"

        Image {
            anchors.fill: parent
            source: Session.wallpaper ? "file://" + Session.wallpaper : ""
            sourceSize: Qt.size(width, height)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: 0.5
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: Qt.alpha(Colours.palette.m3surface, 0.9)
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha(Colours.palette.m3surface, 0.2)
                }
            }
        }
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: Tokens.spacing.large
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spacing.large

        ClippingRectangle {
            width: 64
            height: 64
            radius: 32
            color: Colours.roleFill("primary", "soft", 0)

            Image {
                id: face

                anchors.fill: parent
                source: "file://" + Session.home + "/.face"
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            StyledText {
                visible: face.status !== Image.Ready
                anchors.centerIn: parent
                text: (Session.realName || Session.user).charAt(0).toUpperCase()
                color: Colours.roleInk("primary", "soft")
                font.family: Tokens.font.serif
                font.pixelSize: 30
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            StyledText {
                text: Session.realName || Session.user
                color: root.ink
                font.family: Tokens.font.serif
                font.pixelSize: Tokens.font.title
            }

            MicroLabel {
                text: `${Session.user}@${Session.host}`
            }

            Row {
                spacing: 4

                MaterialIcon {
                    text: "schedule"
                    size: 14
                    color: root.subInk
                }

                MicroLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text: `up ${Session.formatUptime()}`
                }
            }
        }
    }
}
