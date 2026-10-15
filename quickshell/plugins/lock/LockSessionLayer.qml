pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// What the lock shows of the running session in its own place, on the
// shell's primitives (the lock's host hands it to the surface; the login
// screen has its session picker there): what's playing, a card bottom left.
// The notifications, the OSD and capture grow out of the lock's frame
// instead (LockPanels).
Item {
    id: root

    property real sc: 1
    property real edge: 60
    property var ctx: null

    // ── What's playing: a card as the cultivator's beside it ──
    // The cover as the card's cover under an ink fade, the art itself, title
    // and artist, the controls, and how far in along the bottom.
    Surface {
        id: player

        readonly property var mp: Media.active
        readonly property real length: mp?.length ?? 0

        x: root.edge
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 44 * root.sc
        visible: mp !== null
        level: 2
        // As wide as the session's three buttons across the cultivator.
        width: (3 * 100 + 2 * 10) * root.sc
        height: 100 * root.sc
        // The panels' paper (fibre and wash), not a flat fill.
        fill: "transparent"

        // MPRIS only updates the position when asked.
        Timer {
            running: player.visible && Media.playing
            interval: 1000
            repeat: true
            triggeredOnStart: true
            onTriggered: player.mp?.positionChanged()
        }

        PaperSheet {
            anchors.fill: parent
            radius: player.restRadius
        }

        ClippingRectangle {
            anchors.fill: parent
            radius: player.restRadius
            color: "transparent"

            Image {
                anchors.fill: parent
                source: Media.art
                sourceSize: Qt.size(Math.max(64, Math.ceil(width)), Math.max(64, Math.ceil(height)))
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: 0.4
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: Qt.alpha(Colours.palette.m3surface, 0.92)
                    }
                    GradientStop {
                        position: 1
                        color: Qt.alpha(Colours.palette.m3surface, 0.3)
                    }
                }
            }

            // How far in.
            Rectangle {
                anchors.bottom: parent.bottom
                height: 2
                width: parent.width * (player.length > 0 ? Math.min(1, (player.mp?.position ?? 0) / player.length) : 0)
                color: Colours.palette.m3primary
                opacity: 0.8
            }
        }

        // The art, a square at a card's rounding.
        ClippingRectangle {
            id: art

            anchors.left: parent.left
            anchors.leftMargin: 18 * root.sc
            anchors.verticalCenter: parent.verticalCenter
            width: 62 * root.sc
            height: width
            radius: Tokens.rounding.normal
            color: Colours.roleFill("paper", "soft", 4)

            MaterialIcon {
                anchors.centerIn: parent
                visible: artImg.status !== Image.Ready
                text: "music_note"
                size: 26
                color: Colours.palette.m3onSurfaceVariant
            }

            Image {
                id: artImg

                anchors.fill: parent
                source: Media.art
                sourceSize: Qt.size(128, 128)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }

        Column {
            anchors.left: art.right
            anchors.leftMargin: 14 * root.sc
            anchors.right: parent.right
            anchors.rightMargin: 14 * root.sc
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            StyledText {
                width: parent.width
                elide: Text.ElideRight
                text: Media.title || player.mp?.identity || ""
                font.family: Tokens.font.serif
                font.pixelSize: 16 * root.sc
            }

            MicroLabel {
                width: parent.width
                elide: Text.ElideRight
                text: Media.artist || (Media.playing ? "Playing" : "Paused")
            }

            Item {
                width: 1
                height: 4
            }

            // The controls, under the title.
            Row {
                id: controls

                spacing: Tokens.spacing.small

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "skip_previous"
                    size: 30
                    onClicked: {
                        root.ctx?.poke();
                        Media.previous();
                    }
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Media.playing ? "pause" : "play_arrow"
                    size: 34
                    filled: true
                    onClicked: {
                        root.ctx?.poke();
                        Media.playPause();
                    }
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "skip_next"
                    size: 30
                    onClicked: {
                        root.ctx?.poke();
                        Media.next();
                    }
                }
            }
        }

    }
}
