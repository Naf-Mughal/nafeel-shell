// Wallpaper rotation: the wallpaper changes on its own every so often, from a
// pool you pick (everything, favourites, a folder, or what the picker shows
// now), shuffled or in order, never repeating until the pool has gone round.
// Day and night: two folders, swapped at the real sunrise and sunset (the
// weather's, 06:00 / 18:00 without it). After Ryoku's playlist and day/night
// rotation (ryogami daemon, MIT), as a shell service.
//
// Every change is an ordinary Wallpapers.set: the theme follows, under the
// ink. Nothing rotates while the screen is locked.
//
// IPC: qs -p <shell> ipc call rotation next | toggle | on | off

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

Scope {
    id: root

    readonly property string stateFile: Quickshell.env("HOME") + "/.local/state/nafeel-shell/rotation.json"

    // Rotation's settings: a section of the Settings panel's Wallpaper page
    // (the picker's rotation controls set the same keys).
    readonly property SettingsPage settings: SettingsPage {
        name: "wallpaper"
        order: 21

        SettingItem {
            key: "rotation.enabled"
            kind: "toggle"
            icon: "autorenew"
            section: "Rotation"
            label: "Rotate wallpapers"
            description: "The wallpaper changes on its own; never repeats until the pool has gone round."
            def: false
        }
        SettingItem {
            key: "rotation.minutes"
            label: "Every"
            def: 60
            shown: root.enabled
            options: [15, 30, 60, 180, 360, 1440].map(m => ({
                        value: m,
                        icon: "schedule",
                        label: m < 60 ? `${m} min` : m < 1440 ? `${m / 60} h` : "1 day"
                    }))
        }
        SettingItem {
            key: "rotation.from"
            label: "From"
            def: "all"
            shown: root.enabled && !root.dayNight
            options: [
                {
                    value: "all",
                    icon: "photo_library",
                    label: "Everything"
                },
                {
                    value: "favourites",
                    icon: "favorite",
                    label: "Favourites"
                },
                {
                    value: "shown",
                    icon: "filter_list",
                    label: "What the picker shows"
                }
            ].concat(Wallpapers.folders.map(f => ({
                        value: `folder:${f}`,
                        icon: "folder",
                        label: f || "Top level"
                    })))
        }
        SettingItem {
            key: "rotation.order"
            label: "Order"
            def: "random"
            shown: root.enabled
            options: [
                {
                    value: "random",
                    icon: "shuffle",
                    label: "Shuffled"
                },
                {
                    value: "sequence",
                    icon: "format_list_numbered",
                    label: "In order"
                }
            ]
        }
        SettingItem {
            key: "rotation.dayNight"
            kind: "toggle"
            icon: "routine"
            label: "Day and night"
            description: "Two folders, swapped at the real sunrise and sunset."
            def: false
            shown: root.enabled
        }
        SettingItem {
            key: "rotation.dayFolder"
            label: "Day folder"
            def: ""
            shown: root.enabled && root.dayNight
            options: Wallpapers.folders.map(f => ({
                        value: f,
                        icon: "folder",
                        label: f || "Top level"
                    }))
        }
        SettingItem {
            key: "rotation.nightFolder"
            label: "Night folder"
            def: ""
            shown: root.enabled && root.dayNight
            options: Wallpapers.folders.map(f => ({
                        value: f,
                        icon: "folder",
                        label: f || "Top level"
                    }))
        }
    }

    readonly property bool enabled: settings.v["rotation.enabled"] === true
    // Minutes between changes.
    readonly property int minutes: settings.v["rotation.minutes"]
    // "all" | "favourites" | "shown" | "folder:<name>"
    readonly property string from: settings.v["rotation.from"]
    // "random" | "sequence"
    readonly property string order: settings.v["rotation.order"]
    readonly property bool dayNight: settings.v["rotation.dayNight"] === true
    readonly property string dayFolder: settings.v["rotation.dayFolder"]
    readonly property string nightFolder: settings.v["rotation.nightFolder"]

    function setEnabled(on: bool): void {
        Settings.set("rotation.enabled", on);
    }

    // Paths shown since the pool last went round (no repeats till then).
    property var seen: []
    property bool loaded: false

    readonly property var everyChoices: settings.items[1].options.map(o => o.value)

    // Is it day: between today's sunrise and sunset.
    property bool isDay: true
    function _phase(): bool {
        const now = new Date();
        const today = Weather.days?.[0];
        if (today?.sunrise_iso && today?.sunset_iso) {
            const up = new Date(today.sunrise_iso), down = new Date(today.sunset_iso);
            if (!isNaN(up) && !isNaN(down))
                return now >= up && now < down;
        }
        const h = now.getHours();
        return h >= 6 && h < 18;
    }

    function pool(): var {
        let walls = Wallpapers.all;
        if (dayNight) {
            const folder = isDay ? dayFolder : nightFolder;
            if (folder)
                return walls.filter(w => w.folder === folder);
        }
        if (from === "favourites")
            walls = walls.filter(w => Wallpapers.favourites[w.path]);
        else if (from === "shown")
            walls = Wallpapers.shown;
        else if (from.startsWith("folder:"))
            walls = walls.filter(w => w.folder === from.slice(7));
        return walls;
    }

    function next(): void {
        if (ShellState.locked)
            return;
        const walls = pool().filter(w => w.path !== Wallpapers.current);
        if (walls.length === 0)
            return;
        let fresh = walls.filter(w => !seen.includes(w.path));
        if (fresh.length === 0) {
            // Round again.
            seen = [];
            fresh = walls;
        }
        let pick;
        if (order === "sequence") {
            const all = pool();
            const i = all.findIndex(w => w.path === Wallpapers.current);
            pick = all[(i + 1) % all.length];
            if (pick.path === Wallpapers.current)
                return;
        } else {
            pick = fresh[Math.floor(Math.random() * fresh.length)];
        }
        seen = [...seen.slice(-500), pick.path];
        save();
        Wallpapers.set(pick.path);
    }

    // Only what's been shown is rotation's own state; its settings are
    // Settings'.
    function save(): void {
        if (!loaded)
            return;
        file.setText(JSON.stringify({
            seen
        }, null, 2) + "\n");
    }

    onEnabledChanged: {
        if (enabled)
            tick.restart();
    }
    onMinutesChanged: tick.restart()
    onFromChanged: {
        seen = [];
        save();
    }
    onDayNightChanged: isDay = _phase()

    Timer {
        id: tick

        running: root.enabled
        repeat: true
        interval: Math.max(1, root.minutes) * 60000
        onTriggered: root.next()
    }

    // Sunrise and sunset: with day/night on, the pool changes, so does the
    // wallpaper (checked each minute).
    Timer {
        running: root.enabled && root.dayNight
        repeat: true
        interval: 60000
        triggeredOnStart: true
        onTriggered: {
            const day = root._phase();
            if (day !== root.isDay) {
                root.isDay = day;
                root.next();
            }
        }
    }

    // A change was missed while locked: catch up once unlocked.
    Connections {
        target: ShellState

        function onLockedChanged(): void {
            if (!ShellState.locked && root.enabled && root.dayNight && root._phase() !== root.isDay) {
                root.isDay = root._phase();
                root.next();
            }
        }
    }

    IpcHandler {
        target: "rotation"

        function next(): void {
            root.next();
        }
        function toggle(): void {
            root.setEnabled(!root.enabled);
        }
        function on(): void {
            root.setEnabled(true);
        }
        function off(): void {
            root.setEnabled(false);
        }
    }

    FileView {
        id: file

        path: root.stateFile
        printErrors: false
        onLoaded: {
            try {
                const s = JSON.parse(text());
                root.seen = s.seen ?? [];
                // Before settings: rotation kept its own; carried over once.
                const keys = ["enabled", "minutes", "from", "order", "dayNight", "dayFolder", "nightFolder"];
                for (const k of keys)
                    if (k in s && !(`rotation.${k}` in Settings.values))
                        Settings.set(`rotation.${k}`, s[k]);
            } catch (e) {}
            root.isDay = root._phase();
            root.loaded = true;
        }
        onLoadFailed: {
            root.isDay = root._phase();
            root.loaded = true;
        }
    }
}
