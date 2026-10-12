pragma Singleton

// The shell's design tokens: every size, radius, type size and motion value
// comes from here, and nothing else hardcodes one. Radius, motion tempo,
// immersion and paper follow the Appearance settings declared here.
//
// The look is xianxia (cave-abode's ink, mist, paper, gold, jade and
// cinnabar, carried by the Material roles of the wallpaper palette) with
// Material 3 Expressive behaviour: spring motion and shape morphing.

import QtQuick
import Quickshell

Singleton {
    id: root

    // The look's settings (the Settings panel's Appearance page).
    readonly property SettingsPage settings: SettingsPage {
        name: "appearance"
        title: "Appearance"
        gloss: "外观"
        icon: "palette"
        order: 10
        description: "The shell's shape, atmosphere, tempo and paper."

        SettingItem {
            key: "radius"
            label: "Corner rounding"
            description: "How round panels, cards and controls are. Pressed and active controls round a little further."
            def: "restrained"
            options: [
                {
                    value: "tight",
                    icon: "crop_square",
                    label: "Tight"
                },
                {
                    value: "compact",
                    icon: "rounded_corner",
                    label: "Compact"
                },
                {
                    value: "restrained",
                    icon: "rectangle",
                    label: "Restrained"
                },
                {
                    value: "relaxed",
                    icon: "crop_7_5",
                    label: "Relaxed"
                },
                {
                    value: "generous",
                    icon: "circle",
                    label: "Generous"
                }
            ]
        }
        SettingItem {
            key: "paper"
            label: "Paper"
            description: "The frame and panels as frosted paper: translucent over a soft blur of what's behind, with paper fibre. Text and controls stay solid."
            def: "85"
            options: [
                {
                    value: "90",
                    icon: "texture",
                    label: "Dense 90%"
                },
                {
                    value: "85",
                    icon: "blur_on",
                    label: "Frosted 85%"
                },
                {
                    value: "80",
                    icon: "blur_linear",
                    label: "Airy 80%"
                },
                {
                    value: "solid",
                    icon: "square",
                    label: "Solid"
                }
            ]
        }
        SettingItem {
            key: "paperTexture"
            kind: "number"
            label: "Paper texture"
            description: "The fibres in the frame's and panels' paper, light or dark."
            def: 100
            min: 0
            max: 200
            step: 10
            unit: "%"
            zeroLabel: "Off"
        }
        SettingItem {
            key: "immersion"
            label: "Xianxia immersion"
            description: "How much of the ink-wash world shows: drifting mist, particles and textures behind panels, or ornament on the frame only."
            def: "immersive"
            options: [
                {
                    value: "immersive",
                    icon: "landscape",
                    label: "Fully immersive"
                },
                {
                    value: "ornament",
                    icon: "filter_frames",
                    label: "Frame only"
                }
            ]
        }
        SettingItem {
            key: "motion"
            label: "Motion"
            description: "The tempo of every animation."
            def: "normal"
            options: [
                {
                    value: "normal",
                    icon: "play_arrow",
                    label: "Normal"
                },
                {
                    value: "brisk",
                    icon: "fast_forward",
                    label: "Brisk"
                },
                {
                    value: "reduced",
                    icon: "motion_photos_off",
                    label: "Reduced"
                }
            ]
        }
    }

    // ── Frame ─────────────────────────────────────────────────────────────
    // A border round the screen, thicker on the left where the bar sits.
    readonly property int border: 14
    readonly property int barWidth: 52
    readonly property int frameRounding: shape.frame
    // The concave fillet where a drawer joins the frame: the panel radius,
    // as Noctalia draws its concave corners.
    readonly property int frameSmoothing: Math.max(6, shape.panel)

    // ── Shape ─────────────────────────────────────────────────────────────
    // Five presets; `morph` is how far a pressed/active control rounds.
    readonly property var shapes: ({
            tight: { frame: 8, panel: 4, card: 4, control: 4, morph: 6 },
            compact: { frame: 12, panel: 6, card: 6, control: 6, morph: 12 },
            restrained: { frame: 16, panel: 12, card: 10, control: 8, morph: 14 },
            relaxed: { frame: 20, panel: 16, card: 14, control: 12, morph: 18 },
            generous: { frame: 24, panel: 24, card: 18, control: 16, morph: 24 }
        })
    readonly property var shape: shapes[settings.v.radius] ?? shapes.restrained

    readonly property QtObject rounding: QtObject {
        readonly property int small: root.shape.control
        readonly property int normal: root.shape.card
        readonly property int large: root.shape.panel
        readonly property int morph: root.shape.morph
        // True circles only: dots, knobs, badges.
        readonly property int full: 1000
    }

    // ── Space ─────────────────────────────────────────────────────────────
    readonly property QtObject spacing: QtObject {
        readonly property int tiny: 4
        readonly property int small: 6
        readonly property int normal: 10
        readonly property int large: 16
        readonly property int huge: 24
    }

    // A hairline: depth is a line, not a glow.
    readonly property int hairline: 1

    // ── Type ──────────────────────────────────────────────────────────────
    // Serif for display and seals (the cave-abode voice), the UI sans for
    // language, mono for tracked micro-labels and data.
    readonly property QtObject font: QtObject {
        readonly property string serif: "Noto Serif"
        readonly property string cjk: "Noto Serif CJK SC"
        readonly property string mono: "JetBrainsMono Nerd Font"

        readonly property int hero: 34
        readonly property int title: 20
        readonly property int value: 17
        readonly property int row: 14
        readonly property int body: 13
        readonly property int small: 12
        readonly property int micro: 10
        readonly property int tiny: 9

        // Tracking for uppercase mono labels: the printed-instrument feel.
        readonly property real trackLabel: 1.4
        readonly property real trackMark: 2.2
    }

    // How strong the paper's fibres are (0 = none).
    readonly property real paperTexture: settings.v.paperTexture / 100

    // ── Immersion ─────────────────────────────────────────────────────────
    // Fully immersive draws mist, particles and ink texture behind panels too;
    // ornament keeps them to the frame and hero spots.
    readonly property bool immersive: settings.v.immersion !== "ornament"

    // ── Motion ────────────────────────────────────────────────────────────
    readonly property bool reduceMotion: settings.v.motion === "reduced"
    // How long motion takes, as a multiple of the designed timing: normal at
    // the designed speed (1), brisk quicker (0.7).
    readonly property real tempo: settings.v.motion === "brisk" ? 0.7 : 1

    function dur(ms: int): int {
        return reduceMotion ? 0 : Math.round(ms * tempo);
    }

    // A SpringAnimation's spring and damping at the tempo: time scaled by t
    // takes the stiffness over t^2 and the damping over t, so it bounces the
    // same, only slower.
    function springK(k: real): real {
        return reduceMotion ? 60 : k / (tempo * tempo);
    }

    function dampK(d: real): real {
        return reduceMotion ? 1 : d / tempo;
    }

    readonly property QtObject anim: QtObject {
        readonly property int hover: root.dur(100)
        readonly property int fast: root.dur(180)
        readonly property int normal: root.dur(320)
        readonly property int slow: root.dur(520)
        readonly property int swap: root.dur(220)

        // Material 3 (Expressive) easing curves.
        readonly property list<real> standard: [0.2, 0, 0, 1, 1, 1]
        readonly property list<real> emphasized: [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82, 0.25, 1, 1, 1]
        readonly property list<real> emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
        readonly property list<real> emphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
        readonly property list<real> expressiveSpatial: [0.38, 1.21, 0.22, 1, 1, 1]
        readonly property list<real> expressiveFastSpatial: [0.42, 1.67, 0.21, 0.9, 1, 1]
        readonly property list<real> expressiveEffects: [0.34, 0.8, 0.34, 1, 1, 1]
    }

    // Spring presets for SpringAnimation (M3 Expressive physics): `spatial`
    // for things that travel or grow (drawers, pills), `bouncy` for small
    // playful ones (toggles, presses), `gentle` for large surfaces.
    readonly property QtObject spring: QtObject {
        readonly property QtObject spatial: QtObject {
            readonly property real spring: root.springK(3.4)
            readonly property real damping: root.dampK(0.3)
        }
        readonly property QtObject bouncy: QtObject {
            readonly property real spring: root.springK(4.5)
            readonly property real damping: root.dampK(0.22)
        }
        readonly property QtObject gentle: QtObject {
            readonly property real spring: root.springK(2.6)
            readonly property real damping: root.dampK(0.38)
        }
    }

    // The frame's goo: a drawer squashes and stretches with its own velocity
    // and an underdamped spring settles it (Ryoku / Caelestia's BlobRect).
    readonly property QtObject goo: QtObject {
        readonly property bool enabled: !root.reduceMotion
        readonly property real stiffness: 200 / (root.tempo * root.tempo)
        readonly property real damping: 16 / root.tempo
        readonly property real scale: 0.00028
        readonly property real maxStretch: 0.22
    }

    // ── Transparency ──────────────────────────────────────────────────────
    // Translucent surfaces (Caelestia's layering). Off until umbriel blurs the
    // shell's layers behind them.
    // Frosted paper (the paper setting): the frame and panel surfaces at this
    // opacity over umbriel's blur; containers inside stay solid sheets.
    readonly property QtObject transparency: QtObject {
        readonly property bool enabled: root.settings.v.paper !== "solid"
        readonly property real base: enabled ? Number(root.settings.v.paper) / 100 : 1
        readonly property real layers: 1
    }
}
