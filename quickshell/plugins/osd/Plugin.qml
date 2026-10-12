// The OSD plugin's root (Plugins.instance("osd")). The on-screen display: volume, microphone and brightness as a slider, and
// as a label: Wi-Fi, Bluetooth, power profile, do not disturb, caffeine, night
// light, Caps/Num Lock, keyboard layout, and privacy (microphone in use, screen
// being shared).
// It shows for a moment on any change (keys, apps, Noctalia), except at
// startup, and a level stays quiet while a drawer showing its slider is open.

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.config
import qs.services

Scope {
    id: root

    // "volume" | "mic" | "brightness" | "toggle"
    property string kind: ""
    property string icon: ""
    property string label: ""
    property real value: 0
    property bool shown: false
    property bool ready: false

    // The Settings panel's On-screen display page: how long it stays, and
    // which changes it shows.
    readonly property SettingsPage settings: SettingsPage {
        name: "osd"
        title: "On-screen display"
        gloss: "提示"
        icon: "picture_in_picture_alt"
        order: 55
        description: "The pill out of the top bar when something changes."

        SettingItem {
            key: "osd.duration"
            kind: "number"
            label: "Stays for"
            description: "How long it shows after the last change."
            def: 1.4
            min: 0.6
            max: 5
            step: 0.2
            unit: " s"
        }
        SettingItem {
            key: "osd.volume"
            kind: "toggle"
            icon: "volume_up"
            section: "Shows"
            label: "Volume"
            def: true
        }
        SettingItem {
            key: "osd.mic"
            kind: "toggle"
            icon: "mic"
            label: "Microphone level"
            def: true
        }
        SettingItem {
            key: "osd.brightness"
            kind: "toggle"
            icon: "light_mode"
            label: "Brightness"
            def: true
        }
        SettingItem {
            key: "osd.radios"
            kind: "toggle"
            icon: "wifi"
            label: "Wi-Fi and Bluetooth"
            def: true
        }
        SettingItem {
            key: "osd.power"
            kind: "toggle"
            icon: "bolt"
            label: "Power profile"
            def: true
        }
        SettingItem {
            key: "osd.dnd"
            kind: "toggle"
            icon: "notifications_off"
            label: "Do not disturb"
            def: true
        }
        SettingItem {
            key: "osd.display"
            kind: "toggle"
            icon: "nightlight"
            label: "Night light and caffeine"
            def: true
        }
        SettingItem {
            key: "osd.lockKeys"
            kind: "toggle"
            icon: "keyboard_capslock"
            label: "Caps Lock and Num Lock"
            def: true
        }
        SettingItem {
            key: "osd.layout"
            kind: "toggle"
            icon: "keyboard"
            label: "Keyboard layout"
            def: true
        }
        SettingItem {
            key: "osd.privacy"
            kind: "toggle"
            icon: "screen_share"
            label: "Privacy: microphone in use, screen shared"
            def: true
        }
    }

    // Drawers that already show a level (its slider is right there).
    readonly property var showsLevels: ["bar:sound", "actions", "command"]

    function show(k: string, icon: string, label: string, value: real, what: string): void {
        if (!ready || settings.v[`osd.${what}`] === false)
            return;
        const open = ShellState.pinned || ShellState.previewed;
        if (k !== "toggle" && showsLevels.includes(open))
            return;
        kind = k;
        root.icon = icon;
        root.label = label;
        root.value = value;
        shown = true;
        hide.restart();
    }

    Timer {
        running: true
        interval: 2500
        onTriggered: root.ready = true
    }

    Timer {
        id: hide

        interval: Math.round(root.settings.v["osd.duration"] * 1000)
        onTriggered: root.shown = false
    }

    Connections {
        target: Audio

        function onVolumeChanged(): void {
            root.show("volume", Audio.muted ? "volume_off" : Audio.volume < 0.5 ? "volume_down" : "volume_up", "", Audio.volume, "volume");
        }
        function onMutedChanged(): void {
            root.show("volume", Audio.muted ? "volume_off" : "volume_up", "", Audio.muted ? 0 : Audio.volume, "volume");
        }
        function onSourceVolumeChanged(): void {
            root.show("mic", Audio.sourceMuted ? "mic_off" : "mic", "", Audio.sourceVolume, "mic");
        }
        function onSourceMutedChanged(): void {
            root.show("mic", Audio.sourceMuted ? "mic_off" : "mic", "", Audio.sourceMuted ? 0 : Audio.sourceVolume, "mic");
        }
    }

    Connections {
        target: Brightness

        // (From raw: `level` may not have caught up yet here.)
        function onRawChanged(): void {
            if (Brightness.quiet)
                return;
            const level = Brightness.max > 0 ? Brightness.raw / Brightness.max : 0;
            root.show("brightness", level < 0.5 ? "brightness_low" : "light_mode", "", level, "brightness");
        }
    }

    Connections {
        target: Network

        function onWifiEnabledChanged(): void {
            root.show("toggle", Network.wifiEnabled ? "wifi" : "wifi_off", Network.wifiEnabled ? "Wi-Fi on" : "Wi-Fi off", 0, "radios");
        }
    }

    Connections {
        target: BluetoothState

        function onEnabledChanged(): void {
            root.show("toggle", BluetoothState.enabled ? "bluetooth" : "bluetooth_disabled", BluetoothState.enabled ? "Bluetooth on" : "Bluetooth off", 0, "radios");
        }
    }

    Connections {
        target: PowerProfiles

        function onProfileChanged(): void {
            const p = PowerProfiles.profile;
            root.show("toggle", p === PowerProfile.PowerSaver ? "eco" : p === PowerProfile.Performance ? "speed" : "balance", p === PowerProfile.PowerSaver ? "Power saver" : p === PowerProfile.Performance ? "Performance" : "Balanced", 0, "power");
        }
    }

    Connections {
        // The notifications plugin's server, when it's on.
        target: Plugins.instance("notifications")?.notifs ?? null

        function onDndChanged(): void {
            const n = Plugins.instance("notifications").notifs;
            root.show("toggle", n.dnd ? "notifications_off" : "notifications", n.dnd ? "Do not disturb on" : "Do not disturb off", 0, "dnd");
        }
    }

    Connections {
        target: Display

        function onCaffeineChanged(): void {
            root.show("toggle", "coffee", Display.caffeine ? "Caffeine on" : "Caffeine off", 0, "display");
        }
        function onNightLightChanged(): void {
            root.show("toggle", "nightlight", Display.nightLight ? "Night light on" : "Night light off", 0, "display");
        }
    }

    Connections {
        target: LockKeys

        function onCapsChanged(): void {
            root.show("toggle", "keyboard_capslock", LockKeys.caps ? "Caps Lock on" : "Caps Lock off", 0, "lockKeys");
        }
        function onNumChanged(): void {
            root.show("toggle", "dialpad", LockKeys.num ? "Num Lock on" : "Num Lock off", 0, "lockKeys");
        }
    }

    Connections {
        target: Umbriel

        function onLayoutIndexChanged(): void {
            root.show("toggle", "keyboard", Umbriel.layout, 0, "layout");
        }
        function onScreencastChanged(): void {
            if (Umbriel.screencast)
                root.show("toggle", "screen_share", "Screen is being shared", 0, "privacy");
        }
    }

    Connections {
        target: Audio

        function onMicInUseChanged(): void {
            if (Audio.micInUse)
                root.show("toggle", "mic", `Microphone in use · ${Audio.streamName(Audio.recorders[0])}`, 0, "privacy");
        }
    }
}
