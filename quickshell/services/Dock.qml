pragma Singleton

// The dock's apps: pinned ones in their order, then any other running app,
// each with its windows from umbriel. An app is its desktop entry: a pin and
// its windows meet even when the window's app id isn't the pin's (Dolphin's
// windows are org.kde.dolphin, VS Code's com.microsoft.VSCode).
//
// The pins and the dock's behaviour are the Settings panel's Dock page
// (right-clicking an app in the dock pins or unpins it there too).

import QtQuick
import Quickshell
import qs.config

Singleton {
    id: root

    readonly property SettingsPage settings: SettingsPage {
        name: "dock"
        title: "Dock"
        gloss: "停靠"
        icon: "dock_to_bottom"
        order: 13
        description: "The apps at the bottom, and the command center in their middle."

        SettingItem {
            key: "dock.pinned"
            kind: "multi"
            label: "Pinned apps"
            description: "Right-click an app in the dock to pin or unpin it; here, untick one to unpin it."
            def: ["google-chrome", "foot", "org.kde.dolphin", "com.microsoft.VSCode"]
            options: root.pinned.map(id => ({
                        value: id,
                        icon: "push_pin",
                        label: Apps.forAppId(id)?.name ?? id
                    }))
        }
        SettingItem {
            key: "dock.iconStyle"
            label: "Icon style"
            description: "Original: the apps' own icons. Themed: a symbol for the kind of app in the palette's colours, changing with the theme. Tinted: the apps' icons in those colours."
            def: "original"
            options: [
                {
                    value: "themed",
                    icon: "palette",
                    label: "Themed"
                },
                {
                    value: "tinted",
                    icon: "format_color_fill",
                    label: "Tinted"
                },
                {
                    value: "original",
                    icon: "apps",
                    label: "Original"
                }
            ]
        }
        SettingItem {
            key: "dock.iconSize"
            kind: "number"
            label: "Icon size"
            def: 40
            min: 28
            max: 52
            step: 2
            unit: " px"
        }
        SettingItem {
            key: "dock.showRunning"
            kind: "toggle"
            icon: "apps"
            label: "Show other running apps"
            description: "Apps with windows open that aren't pinned join the dock while they run."
            def: true
        }
        SettingItem {
            key: "dock.previewHeight"
            kind: "number"
            label: "Window previews"
            description: "How tall the live previews are that grow out of the dock over an app."
            def: 150
            min: 90
            max: 260
            step: 10
            unit: " px"
        }
        SettingItem {
            key: "dock.windowsDelay"
            kind: "number"
            section: "Hover"
            label: "Preview an app's windows after"
            description: "Resting on a running app grows the dock with live previews of its windows."
            def: 250
            min: 0
            max: 1000
            step: 50
            unit: " ms"
        }
        SettingItem {
            key: "dock.centerDelay"
            kind: "number"
            label: "Open the command center after"
            description: "Resting on the icon in the middle of the dock opens it."
            def: 200
            min: 0
            max: 1000
            step: 50
            unit: " ms"
        }
    }

    readonly property var pinned: settings.v["dock.pinned"] ?? []

    // An app's identity: its desktop entry's id, else its app id.
    function key(appId: string): string {
        return (Apps.forAppId(appId)?.id ?? appId ?? "").toLowerCase();
    }

    // [{ appId, pinned, windows: [umbriel window…] }]
    readonly property var items: {
        const byKey = {};
        const order = [];
        for (const w of Umbriel.windows) {
            const k = key(w.app_id);
            if (!byKey[k]) {
                byKey[k] = {
                    appId: w.app_id,
                    windows: []
                };
                order.push(k);
            }
            byKey[k].windows.push(w);
        }
        const pinnedKeys = pinned.map(p => key(p));
        const out = pinned.map((id, i) => ({
                    appId: id,
                    pinned: true,
                    windows: byKey[pinnedKeys[i]]?.windows ?? []
                }));
        if (settings.v["dock.showRunning"])
            for (const k of order)
                if (!pinnedKeys.includes(k))
                    out.push({
                        appId: byKey[k].appId,
                        pinned: false,
                        windows: byKey[k].windows
                    });
        return out;
    }

    function togglePin(appId: string): void {
        const k = key(appId);
        const has = pinned.some(p => key(p) === k);
        Settings.set("dock.pinned", has ? pinned.filter(p => key(p) !== k) : pinned.concat([appId]));
    }

    // Focus the app (cycling through its windows), or start it.
    function activate(item: var): void {
        if (item.windows.length === 0) {
            const entry = Apps.forAppId(item.appId);
            if (entry)
                entry.execute();
            else
                Quickshell.execDetached([item.appId]);
            return;
        }
        const focused = item.windows.findIndex(w => w.focused);
        const next = item.windows[(focused + 1) % item.windows.length];
        Umbriel.dispatch("window-focus:" + next.id);
    }
}
