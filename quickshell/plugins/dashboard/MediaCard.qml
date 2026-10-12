import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// What's playing: the cover (spinning slowly, like a record, while it plays),
// title and artist, where it is in the track, the controls, and bongocat
// drumming along while it plays. `big` for the
// Media tab.
Surface {
    id: root

    property bool big: false
    readonly property var player: Media.active
    readonly property real length: player?.length ?? 0

    level: 2
    implicitWidth: 220

    // MPRIS only updates the position when asked.
    Timer {
        running: root.visible && Media.playing
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.player?.positionChanged()
    }

    function time(s: real): string {
        s = Math.max(0, Math.floor(s));
        return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - Tokens.spacing.large * 2
        spacing: Tokens.spacing.normal

        // The record, and in the Media tab the music radiating out of it.
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: cover.width + (root.big ? 110 : 0)
            height: width

            RadialVisualiser {
                visible: root.big
                active: root.big && Media.playing
                anchors.fill: parent
                innerRadius: cover.width / 2
            }

        ClippingRectangle {
            id: cover

            anchors.centerIn: parent
            width: Math.min(root.width - Tokens.spacing.large * 2, root.big ? 210 : 150)
            height: width
            radius: width / 2
            color: Colours.roleFill("paper", "soft", 4)

            Image {
                anchors.fill: parent
                source: Media.art
                fillMode: Image.PreserveAspectCrop
                asynchronous: true

                RotationAnimation on rotation {
                    running: Media.playing && !Tokens.reduceMotion
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 24000
                }
            }

            MaterialIcon {
                visible: !Media.art
                anchors.centerIn: parent
                text: "music_note"
                size: cover.width / 3
                color: root.subInk
            }

            // The record's hole.
            Rectangle {
                anchors.centerIn: parent
                width: cover.width * 0.12
                height: width
                radius: width / 2
                color: Colours.roleFill("paper", "soft", 2)
                visible: !!Media.art
            }
        }
        }

        Column {
            width: parent.width
            spacing: 2

            StyledText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: Media.title || "Nothing playing"
                color: root.ink
                font.pixelSize: root.big ? Tokens.font.title : Tokens.font.row
                font.family: Tokens.font.serif
                elide: Text.ElideRight
            }

            MicroLabel {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: [Media.artist, root.big ? root.player?.trackAlbum ?? "" : ""].filter(x => x).join(" · ")
                elide: Text.ElideRight
            }
        }

        StyledSlider {
            visible: root.length > 0
            width: parent.width
            height: 14
            to: Math.max(1, root.length)
            value: root.player?.position ?? 0
            onMoved: v => {
                if (root.player?.canSeek)
                    root.player.position = v;
            }
        }

        Item {
            visible: root.length > 0 && root.big
            width: parent.width
            height: 14

            MicroLabel {
                text: root.time(root.player?.position ?? 0)
            }

            MicroLabel {
                anchors.right: parent.right
                text: root.time(root.length)
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Tokens.spacing.small

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "skip_previous"
                size: root.big ? 44 : 34
                onClicked: Media.previous()
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: Media.playing ? "pause" : "play_arrow"
                size: root.big ? 52 : 40
                filled: true
                onClicked: Media.togglePlaying()
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "skip_next"
                size: root.big ? 44 : 34
                onClicked: Media.next()
            }
        }

        // Bongocat, drumming along while it plays.
        AnimatedImage {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width, 120)
            height: 64
            source: Qt.resolvedUrl("../../assets/bongocat.gif")
            fillMode: AnimatedImage.PreserveAspectFit
            playing: Media.playing
            asynchronous: true
        }
    }
}
