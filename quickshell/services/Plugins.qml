pragma Singleton

// The kernel's plugin registry. The shell is a kernel (the frame and its
// drawers, the bar and the dock as chrome, Settings, the primitives, the
// platform services, the Bus, the theme, umbriel, IPC) and every feature on
// it is a plugin: a folder in plugins/ with a manifest.
//
//   plugins/<id>/plugin.json
//     { "id", "name", "gloss", "icon", "description",
//       "default": true,       on unless switched off on the Plugins page
//       "root": "Plugin.qml",  made while the plugin is on (instance(id)):
//                              its services, settings page and IPC
//       "drawers": [{ "name", "entry", "edge", "along", "corner",
//                     "width" / "height": a number (capped to the screen)
//                       or "content" (the entry's implicit size),
//                     "keyboard", "hoverZone", "zoneLength", "padding",
//                     "openWhen" / "openIf": a root property that opens it
//                       by itself / must also hold, "yieldTo": [drawers it
//                       stays shut under], "modal", "overFullscreen" }],
//       "overlays": ["Keys.qml"]  items in every frame window, open drawer
//                              or not (they get `shellScreen`),
//       "slots": [{ "slot", "entry", "order" }]  items in places the kernel
//                              leaves open: "bar.top", "bar.actions",
//                              "bar.middle",
//       "popouts": [{ "name", "corner", "entry", "width" }]  a bar corner's
//                              panel, opened as "bar:<name>",
//       "tabs": [{ "id", "icon", "label", "entry", "popout" }]  command
//                              center tabs, after the kernel's; "popout":
//                              true centres a popout-sized panel in it }
//
// A plugin that's off loads nothing: no root, drawers, overlays, slots or
// popouts or tabs. bin/nafeel-shell imports every plugin folder at startup
// (PluginModules.qml), so a plugin's files use each other by name and it
// may keep singletons (made only when used). Code outside a plugin reaches
// it only through instance(id), never by a singleton's name (that would
// start it while it's off).

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property string dir: Quickshell.shellDir + "/plugins"

    // Every plugin found: [{ id, name, …, dir }] in name order.
    property var all: []

    // A plugin file's URL through Quickshell's own scheme (as the shell's
    // files are served), so it sees its neighbours (qs.plugins.<id>) and
    // the kernel's modules; a plain file:// URL would bypass that.
    function urlOf(p: var, file: string): string {
        return Qt.resolvedUrl(`../plugins/${p.dir.split("/").pop()}/${file}`);
    }

    function isOn(p: var): bool {
        const v = Settings.values[`plugin.${p.id}`];
        return v === undefined ? p.default !== false : v === true;
    }

    readonly property var enabled: Settings.loaded ? all.filter(p => isOn(p)) : []
    // Every plugin with a root, on or off (shell.qml keeps a loader for each,
    // active while it's on).
    readonly property var withRoot: all.filter(p => p.root)
    function isEnabled(id: string): bool {
        return enabled.some(p => p.id === id);
    }

    // Every plugin's drawers, on or off, with their entry's url. The frame
    // keeps one for each (a model that only changes on a rescan, so
    // switching a plugin doesn't rebuild the rest) and enables those whose
    // plugin is on.
    readonly property var drawers: all.reduce((out, p) => out.concat((p.drawers ?? []).map(d => Object.assign({}, d, {
                    plugin: p.id,
                    url: urlOf(p, d.entry)
                }))), [])

    // The running roots, by plugin id (shell.qml's loaders fill this):
    // a plugin's files reach their own objects through it, since plugin
    // folders aren't Quickshell modules (they can't hold singletons, and a
    // plugin's objects should go when it's switched off anyway).
    property var instances: ({})

    function instance(id: string): var {
        return instances[id] ?? null;
    }

    function attach(id: string, obj: var): void {
        const next = Object.assign({}, instances);
        if (obj)
            next[id] = obj;
        else
            delete next[id];
        instances = next;
    }

    // Every plugin's frame overlays (items in every frame window, open
    // drawer or not: a plugin's keys, say), on or off as the drawers:
    // [{ plugin, url }].
    readonly property var overlays: all.reduce((out, p) => out.concat((p.overlays ?? []).map(f => ({
                    plugin: p.id,
                    url: urlOf(p, f)
                }))), [])

    // The enabled plugins' command center tabs: [{ id, icon, label, url, popout }].
    readonly property var tabs: enabled.reduce((out, p) => out.concat((p.tabs ?? []).map(t => Object.assign({}, t, {
                    plugin: p.id,
                    url: urlOf(p, t.entry)
                }))), [])

    // The enabled plugins' slot items for `slot`, in order:
    // [{ plugin, url, order }].
    function forSlot(slot: string): var {
        return enabled.reduce((out, p) => out.concat((p.slots ?? []).filter(s => s.slot === slot).map(s => ({
                        plugin: p.id,
                        url: urlOf(p, s.entry),
                        order: s.order ?? 0
                    }))), []).sort((a, b) => a.order - b.order);
    }

    // The enabled plugins' popouts for a bar corner ("topLeft" |
    // "bottomLeft"): { name: { url, width } }.
    function popoutsFor(corner: string): var {
        const out = {};
        for (const p of enabled)
            for (const o of (p.popouts ?? []))
                if ((o.corner ?? "topLeft") === corner)
                    out[o.name] = {
                        url: urlOf(p, o.entry),
                        width: o.width
                    };
        return out;
    }

    // The Settings panel's Plugins page: one switch per plugin.
    readonly property SettingsPage settings: SettingsPage {
        name: "plugins"
        title: "Plugins"
        gloss: "法宝"
        icon: "extension"
        order: 5
        description: "The shell's features, each a plugin; one that's off loads nothing."
        extraItems: toggles.items
    }

    Instantiator {
        id: toggles

        property var items: []

        model: root.all

        delegate: SettingItem {
            required property var modelData

            key: `plugin.${modelData.id}`
            kind: "toggle"
            icon: modelData.icon ?? "extension"
            label: modelData.gloss ? `${modelData.name}  ${modelData.gloss}` : modelData.name
            description: modelData.description ?? ""
            def: modelData.default !== false
        }

        onObjectAdded: (i, o) => items = items.concat([o])
        onObjectRemoved: (i, o) => items = items.filter(x => x !== o)
    }

    function rescan(): void {
        scan.running = true;
    }

    Process {
        id: scan

        running: true
        // One manifest per line: "<dir>\t<json on one line>".
        command: ["sh", "-c", 'for f in "$1"/*/plugin.json; do [ -f "$f" ] && printf "%s\\t%s\\n" "${f%/plugin.json}" "$(tr -d "\\n" < "$f")"; done', "sh", root.dir]

        stdout: StdioCollector {
            onStreamFinished: {
                const found = [];
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 0)
                        continue;
                    try {
                        const p = JSON.parse(line.slice(tab + 1));
                        p.dir = line.slice(0, tab);
                        p.id = p.id ?? p.dir.split("/").pop();
                        found.push(p);
                    } catch (e) {
                        console.warn("plugins: bad plugin.json in", line.slice(0, tab), e);
                    }
                }
                found.sort((a, b) => (a.name ?? a.id).localeCompare(b.name ?? b.id));
                root.all = found;
                console.info(`plugins: ${found.map(p => p.id + (root.isOn(p) ? "" : " (off)")).join(", ")}`);
            }
        }
    }

    IpcHandler {
        target: "plugins"

        function list(): string {
            return root.all.map(p => `${p.id}${root.isOn(p) ? "" : " (off)"}`).join("\n");
        }

        function enable(id: string): void {
            Settings.set(`plugin.${id}`, true);
        }

        function disable(id: string): void {
            Settings.set(`plugin.${id}`, false);
        }
    }
}
