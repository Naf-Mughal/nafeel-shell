pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.config
import qs.services
import qs.components

// Sound, brightness and now playing in one panel: what's playing (when
// something is), the speaker and microphone, the screen's brightness with its
// toggles, and the output devices.
Panel {
    id: root

    icon: Audio.muted ? "volume_off" : "volume_up"
    title: "Sound"
    gloss: Xian.gloss.audio
    subtitle: `${Math.round(Audio.volume * 100)}%${Audio.muted ? " · muted" : ""} · ${Audio.sink?.description ?? ""}`

    property MprisPlayer player: Media.active

    function time(s: real): string {
        s = Math.max(0, Math.floor(s));
        return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
    }

    spacing: Tokens.spacing.normal

    // MPRIS doesn't push the position; ask for it while shown.
    Timer {
        running: root.player?.isPlaying ?? false
        interval: 1000
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    // Now playing.
    Surface {
        visible: root.player !== null
        width: parent.width
        height: 104
        level: 3

        ClippingRectangle {
            id: art

            x: Tokens.spacing.normal
            anchors.verticalCenter: parent.verticalCenter
            width: 84
            height: 84
            radius: Tokens.rounding.small
            color: Colours.palette.m3surfaceContainerHighest

            Image {
                anchors.fill: parent
                source: root.player?.trackArtUrl ?? ""
                sourceSize: Qt.size(168, 168)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            MaterialIcon {
                anchors.centerIn: parent
                visible: !(root.player?.trackArtUrl)
                text: "music_note"
                size: 32
                color: Colours.palette.m3onSurfaceVariant
            }
        }

        Column {
            anchors.left: art.right
            anchors.leftMargin: Tokens.spacing.normal
            anchors.right: parent.right
            anchors.rightMargin: Tokens.spacing.normal
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            StyledText {
                width: parent.width
                text: root.player?.trackTitle || "Unknown track"
                font.pixelSize: Tokens.font.row
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                text: root.player?.trackArtist ?? ""
                visible: text !== ""
                color: Colours.palette.m3onSurfaceVariant
                font.pixelSize: Tokens.font.small
                elide: Text.ElideRight
            }

            StyledSlider {
                width: parent.width
                implicitHeight: 8
                visible: root.player?.lengthSupported ?? false
                value: root.player?.position ?? 0
                to: Math.max(1, root.player?.length ?? 1)
                onMoved: v => {
                    if (root.player?.canSeek)
                        root.player.position = v;
                }
            }

            Row {
                spacing: Tokens.spacing.small

                MicroLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.player?.lengthSupported ?? false
                    text: `${root.time(root.player?.position ?? 0)} / ${root.time(root.player?.length ?? 0)}`
                }

                IconButton {
                    icon: "skip_previous"
                    size: 30
                    onClicked: root.player?.previous()
                }
                IconButton {
                    icon: root.player?.isPlaying ? "pause" : "play_arrow"
                    size: 30
                    filled: true
                    fillColour: Colours.palette.m3primary
                    inkColour: Colours.palette.m3onPrimary
                    onClicked: root.player?.togglePlaying()
                }
                IconButton {
                    icon: "skip_next"
                    size: 30
                    onClicked: root.player?.next()
                }
            }
        }
    }

    SectionLabel {
        text: "Volume"
    }

    VolumeRow {
        width: parent.width
        icon: Audio.muted ? "volume_off" : "volume_up"
        muted: Audio.muted
        value: Audio.volume
        onToggleMute: Audio.toggleMute()
        onMoved: v => Audio.setVolume(v)
    }

    VolumeRow {
        width: parent.width
        visible: Audio.source !== null
        icon: Audio.sourceMuted ? "mic_off" : "mic"
        muted: Audio.sourceMuted
        value: Audio.sourceVolume
        tertiary: true
        onToggleMute: Audio.toggleSourceMute()
        onMoved: v => Audio.setSourceVolume(v)
    }

    SectionLabel {
        visible: Brightness.available
        text: "Display"
    }

    Row {
        visible: Brightness.available
        width: parent.width
        spacing: Tokens.spacing.small

        IconButton {
            icon: "light_mode"
            filled: true
            caption: Math.round(Brightness.level * 100)
        }

        StyledSlider {
            width: parent.width - 40 - Tokens.spacing.small
            value: Brightness.level
            onMoved: v => Brightness.set(v)
        }
    }

    Row {
        width: parent.width
        spacing: Tokens.spacing.small

        Repeater {
            model: [
                { key: "night", icon: "nightlight", label: "Night light" },
                { key: "caffeine", icon: "coffee", label: "Caffeine" },
                { key: "dark", icon: "dark_mode", label: "Dark" }
            ]

            Tile {
                required property var modelData

                width: (root.width - Tokens.spacing.small * 2) / 3
                implicitHeight: 56
                stacked: true
                icon: modelData.icon
                label: modelData.label
                checked: modelData.key === "night" ? Display.nightLight : modelData.key === "caffeine" ? Display.caffeine : !Colours.light
                onClicked: modelData.key === "night" ? Display.toggleNightLight() : modelData.key === "caffeine" ? Display.toggleCaffeine() : Display.toggleDarkMode()
            }
        }
    }

    SectionLabel {
        visible: Audio.sinks.length > 1
        text: "Output"
    }

    Repeater {
        model: Audio.sinks.length > 1 ? Audio.sinks : []

        ListRow {
            required property var modelData

            width: root.width
            icon: (modelData.description ?? "").toLowerCase().includes("hdmi") ? "tv" : (modelData.description ?? "").toLowerCase().includes("headphone") ? "headphones" : "speaker"
            iconFill: Audio.sink === modelData ? 1 : 0
            highlighted: Audio.sink === modelData
            title: modelData.nickname || modelData.description || modelData.name
            onClicked: Audio.setSink(modelData)
        }
    }
}
