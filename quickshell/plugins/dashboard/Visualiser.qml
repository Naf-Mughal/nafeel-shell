pragma Singleton

// The audio visualiser's bars (Caelestia's CavaProvider, native: PipeWire
// capture and cava's core). Capture runs only while something on screen holds
// a ServiceRef to `cava` (RadialVisualiser does), so nothing listens otherwise.

import QtQuick
import Quickshell
import Nafeel
import qs.config
import qs.services

Singleton {
    id: root

    readonly property alias cava: provider
    // The Settings panel's Media page.
    readonly property SettingsPage settings: SettingsPage {
        name: "media"
        title: "Media"
        gloss: "影音"
        icon: "music_note"
        order: 65
        description: "The dashboard's visualiser."

        SettingItem {
            key: "visualiser.bars"
            kind: "number"
            label: "Visualiser bars"
            description: "Strokes round the record: more is finer, fewer is bolder."
            def: 48
            min: 16
            max: 96
            step: 8
        }
    }
    readonly property int bars: settings.v["visualiser.bars"]

    CavaProvider {
        id: provider

        bars: root.bars
    }
}
