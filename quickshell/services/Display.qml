pragma Singleton

// Night light and caffeine, run by the shell itself: the night light through
// the native NightLight (gamma control, Noctalia's maths), caffeine as a
// Wayland idle inhibitor held by each screen's frame (FrameWindow), which
// anything watching for idle respects. Both are remembered in
// ~/.local/state/nafeel-shell/display.json. Dark mode is the Theme page's
// mode setting.

import QtQuick
import Quickshell
import Quickshell.Io
import Nafeel
import qs.config

Singleton {
    id: root

    property bool nightLight: false
    property bool caffeine: false
    // The Settings panel's Display page.
    readonly property SettingsPage settings: SettingsPage {
        name: "display"
        title: "Display"
        gloss: "显示"
        icon: "desktop_windows"
        order: 30
        description: "Night light."

        SettingItem {
            key: "display.nightTemperature"
            kind: "number"
            section: "Night light"
            label: "Warmth"
            description: "The colour temperature while night light is on: lower is warmer."
            def: 4000
            min: 2500
            max: 6000
            step: 100
            unit: " K"
        }
    }
    // The night temperature (Kelvin).
    readonly property int nightTemperature: settings.v["display.nightTemperature"]

    NightLight {
        active: root.nightLight
        temperature: root.nightTemperature
    }

    function save(): void {
        file.setText(JSON.stringify({
            nightLight: nightLight,
            caffeine: caffeine
        }));
    }

    function toggleNightLight(): void {
        nightLight = !nightLight;
        save();
    }

    function toggleCaffeine(): void {
        caffeine = !caffeine;
        save();
    }

    function toggleDarkMode(): void {
        Settings.set("theme.mode", Theme.settings.v["theme.mode"] === "light" ? "dark" : "light");
    }

    // For keybinds: qs -p <shell> ipc call display caffeine | nightLight
    IpcHandler {
        target: "display"

        function caffeine(): void {
            root.toggleCaffeine();
        }

        function nightLight(): void {
            root.toggleNightLight();
        }
    }

    FileView {
        id: file

        path: Quickshell.env("HOME") + "/.local/state/nafeel-shell/display.json"
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.nightLight = !!d.nightLight;
                root.caffeine = !!d.caffeine;
            } catch (e) {}
        }
    }
}
