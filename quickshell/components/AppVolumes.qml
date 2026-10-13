pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services

// A volume row per app playing sound, the same as the speaker's: the app's
// icon and level in the chip (click to mute), its name above the slider.
// Nothing while no app plays.
Column {
    id: root

    spacing: Tokens.spacing.small
    visible: Audio.streams.length > 0

    SectionLabel {
        text: "Apps"
    }

    Repeater {
        // Diffed (ScriptModel): a new array (a signal strength, a stream
        // coming or going) moves or adds rows; rebuilding every row held the GUI
        // thread past a refresh, dropping a frame of whatever was animating.
        model: ScriptModel {
            values: Audio.streams
        }
        Column {
            id: app

            required property var modelData

            width: root.width
            spacing: 2

            StyledText {
                x: 40 + Tokens.spacing.small
                width: parent.width - x
                text: Audio.streamName(app.modelData)
                color: Colours.palette.m3onSurfaceVariant
                font.pixelSize: Tokens.font.small
                elide: Text.ElideRight
            }

            VolumeRow {
                width: parent.width
                appId: Audio.streamAppId(app.modelData)
                muted: !!app.modelData.audio?.muted
                value: app.modelData.audio?.volume ?? 0
                onToggleMute: Audio.toggleStreamMute(app.modelData)
                onMoved: v => Audio.setStreamVolume(app.modelData, v)
            }
        }
    }
}
