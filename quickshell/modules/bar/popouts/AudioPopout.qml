pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
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
            // Diffed (ScriptModel): a new array (a signal strength, a stream
            // coming or going) moves or adds rows; rebuilding every row held the GUI
            // thread past a refresh, dropping a frame of whatever was animating.
            model: ScriptModel {
                values: Audio.sinks
            }
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

    AppVolumes {
        width: parent.width
    }
}
