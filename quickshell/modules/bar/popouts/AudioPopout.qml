pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.components

// Sound: speaker and microphone sliders (the icon chip mutes), the output
// device as tiles, and a slider per app playing sound.
Panel {
    id: root

    gloss: Xian.gloss.audio
    icon: Audio.muted ? "volume_off" : "volume_up"
    title: "Sound"
    subtitle: `${Math.round(Audio.volume * 100)}%${Audio.muted ? " · muted" : ""}`


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
        visible: Audio.sinks.length > 1
        text: "Output"
    }

    Grid {
        visible: Audio.sinks.length > 1
        width: parent.width
        columns: 2
        spacing: Tokens.spacing.small

        Repeater {
            model: Audio.sinks

            Tile {
                required property var modelData

                width: (root.width - Tokens.spacing.small) / 2
                icon: (modelData.description ?? "").toLowerCase().includes("hdmi") ? "tv" : (modelData.description ?? "").toLowerCase().includes("headphone") ? "headphones" : "speaker"
                label: modelData.nickname || modelData.description || modelData.name
                checked: Audio.sink === modelData
                onClicked: Audio.setSink(modelData)
            }
        }
    }

    SectionLabel {
        visible: Audio.streams.length > 0
        text: "Apps"
    }

    Repeater {
        model: Audio.streams

        Column {
            id: app

            required property var modelData

            width: root.width
            spacing: 4

            StyledText {
                text: Audio.streamName(app.modelData)
                color: Colours.palette.m3onSurfaceVariant
                font.pixelSize: 12
                elide: Text.ElideRight
                width: parent.width
            }

            StyledSlider {
                width: parent.width
                implicitHeight: 28
                value: app.modelData.audio?.volume ?? 0
                fill: Colours.palette.m3secondary
                ink: Colours.palette.m3onSecondary
                onMoved: v => {
                    if (app.modelData.audio)
                        app.modelData.audio.volume = Math.min(1, v);
                }
            }
        }
    }
}
