pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.config
import qs.services
import qs.components

// Media: artwork, title and artist, a seek bar, and the transport controls
// with the play button as the big shape-shifting centrepiece. More than one
// player shows chips to switch between them.
Panel {
    id: root

    property MprisPlayer player: Media.active

    function time(s: real): string {
        s = Math.max(0, Math.floor(s));
        return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
    }

    spacing: Tokens.spacing.normal

    EmptyState {
        width: parent.width
        visible: root.player === null
        icon: "music_off"
        title: "Nothing playing"
        hint: "Start something in a player and it shows up here"
    }

    // MPRIS doesn't push the position; ask for it while shown.
    Timer {
        running: root.player?.isPlaying ?? false
        interval: 1000
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    Row {
        visible: Media.players.length > 1
        spacing: Tokens.spacing.small

        Repeater {
            model: Media.players

            Surface {
                id: chip

                required property var modelData

                width: chipText.implicitWidth + Tokens.spacing.large * 2
                height: 30
                shape: "small"
                role: root.player === modelData ? "secondary" : "paper"

                StyledText {
                    id: chipText

                    anchors.centerIn: parent
                    text: chip.modelData.identity
                    color: root.player === chip.modelData ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                    font.pixelSize: 12
                }

                TapHandler {
                    onTapped: root.player = chip.modelData
                }
            }
        }
    }

    ClippingRectangle {
        visible: root.player !== null
        width: parent.width
        height: 180
        radius: Tokens.rounding.large
        color: Colours.palette.m3surfaceContainerHigh

        Image {
            anchors.fill: parent
            source: root.player?.trackArtUrl ?? ""
            sourceSize: Qt.size(640, 360)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        MaterialIcon {
            anchors.centerIn: parent
            visible: !(root.player?.trackArtUrl)
            text: "music_note"
            size: 48
            color: Colours.palette.m3onSurfaceVariant
        }
    }

    Column {
        visible: root.player !== null
        width: parent.width

        StyledText {
            width: parent.width
            text: root.player?.trackTitle || "Nothing playing"
            font.pixelSize: 16
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        StyledText {
            width: parent.width
            text: root.player?.trackArtist ?? ""
            color: Colours.palette.m3onSurfaceVariant
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }

    Column {
        width: parent.width
        visible: root.player?.lengthSupported ?? false
        spacing: 2

        StyledSlider {
            width: parent.width
            implicitHeight: 12
            value: root.player?.position ?? 0
            to: Math.max(1, root.player?.length ?? 1)
            onMoved: v => {
                if (root.player?.canSeek)
                    root.player.position = v;
            }
        }

        Item {
            width: parent.width
            height: 16

            StyledText {
                text: root.time(root.player?.position ?? 0)
                color: Colours.palette.m3onSurfaceVariant
                font.pixelSize: 11
            }

            StyledText {
                anchors.right: parent.right
                text: root.time(root.player?.length ?? 0)
                color: Colours.palette.m3onSurfaceVariant
                font.pixelSize: 11
            }
        }
    }

    Row {
        visible: root.player !== null
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Tokens.spacing.normal

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "skip_previous"
            size: 44
            onClicked: root.player?.previous()
        }

        // Round while paused, a squircle while playing.
        Surface {
            width: 72
            height: 56
            role: "primary"
            emphasis: "strong"
            radius: root.player?.isPlaying ? Tokens.rounding.small : Tokens.rounding.morph * 1.6

            Behavior on radius {
                Anim {
                    easing.bezierCurve: Tokens.anim.expressiveFastSpatial
                }
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: root.player?.isPlaying ? "pause" : "play_arrow"
                fill: 1
                size: 28
                color: Colours.palette.m3onPrimary
            }

            TapHandler {
                onTapped: root.player?.togglePlaying()
            }
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "skip_next"
            size: 44
            onClicked: root.player?.next()
        }
    }
}
