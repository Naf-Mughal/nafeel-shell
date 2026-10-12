pragma Singleton

// The shell's settings: one file the shell owns,
// ~/.config/nafeel-shell/settings.json, read and written here, applied live
// (edits from outside are picked up too).
//
// Settings are declared next to the feature they belong to, as a
// SettingsPage of SettingItems (key, kind, label, default), and read back
// from that page (`page.v.<key>`): the default lives in one place. The
// Settings panel builds a page per declaration. Keys are flat; a feature's
// own prefix ("idle.…") keeps them apart.
//
//   readonly property SettingsPage settings: SettingsPage {
//       name: "weather"; title: "Weather"; gloss: "天气"; icon: "partly_cloudy_day"
//       SettingItem { key: "location"; kind: "text"; label: "Place"; def: "" }
//   }
//   … settings.v.location …
//
// The first run takes the values the Noctalia plugin used to write
// (~/.local/state/nafeel-shell/settings.json).

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string dir: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/nafeel-shell`
    readonly property string path: dir + "/settings.json"

    // What's stored: only what has been set (defaults stay with the
    // declarations).
    property var values: ({})
    property bool loaded: false
    // Every declaration, in panel order; features that share a page name
    // (a section of another feature's page) are listed once in `pages`, and
    // `itemsOf(name)` / `valuesOf(name)` gather all of them.
    property var declarations: []
    readonly property var pages: declarations.filter((p, i) => declarations.findIndex(q => q.name === p.name) === i)

    function itemsOf(name: string): var {
        return declarations.filter(p => p.name === name).reduce((all, p) => all.concat(p.allItems), []);
    }

    function valuesOf(name: string): var {
        return declarations.filter(p => p.name === name).reduce((all, p) => Object.assign(all, p.v), {});
    }

    // Set before the file is read (a feature carrying its old settings
    // over at startup): kept, and applied once loaded where the file has no
    // value of its own, so nothing on disk is overwritten.
    property var early: ({})

    function set(key: string, value: var): void {
        if (!loaded) {
            early[key] = value;
            return;
        }
        if (values[key] === value)
            return;
        const next = Object.assign({}, values);
        next[key] = value;
        values = next;
        save();
    }

    // Back to the declared default.
    function reset(key: string): void {
        if (!(key in values))
            return;
        const next = Object.assign({}, values);
        delete next[key];
        values = next;
        save();
    }

    function finishLoading(): void {
        if (loaded)
            return;
        const missing = Object.keys(early).filter(k => !(k in values));
        if (missing.length > 0) {
            const next = Object.assign({}, values);
            for (const k of missing)
                next[k] = early[k];
            values = next;
        }
        early = {};
        loaded = true;
        if (missing.length > 0)
            save();
    }

    function save(): void {
        file.setText(JSON.stringify(values, null, 2) + "\n");
    }

    function unregister(page: QtObject): void {
        declarations = declarations.filter(p => p !== page);
    }

    function register(page: QtObject): void {
        if (declarations.includes(page))
            return;
        const next = declarations.concat([page]);
        next.sort((a, b) => a.order - b.order);
        declarations = next;
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", dir])

    // qs ipc call settings get <key> | set <key> <value> | reset <key> | list
    // (a value that reads as JSON is taken as JSON: true, 85, "x").
    IpcHandler {
        target: "settings"

        function get(key: string): string {
            for (const page of root.declarations)
                if (key in page.v)
                    return JSON.stringify(page.v[key]);
            return JSON.stringify(root.values[key] ?? null);
        }

        function set(key: string, value: string): void {
            let v = value;
            try {
                v = JSON.parse(value);
            } catch (e) {}
            root.set(key, v);
        }

        function reset(key: string): void {
            root.reset(key);
        }

        function list(): string {
            return root.pages.map(p => `${p.name}: ${root.itemsOf(p.name).map(i => i.key).join(", ")}`).join("\n");
        }
    }

    FileView {
        id: file

        path: root.path
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.values = JSON.parse(text()) ?? {};
            } catch (e) {
                console.warn(`settings: ${root.path} isn't valid JSON; keeping what was loaded`);
            }
            root.finishLoading();
        }
        // First run: what the Noctalia plugin wrote, carried over.
        onLoadFailed: legacy.reload()
    }

    FileView {
        id: legacy

        path: Quickshell.env("HOME") + "/.local/state/nafeel-shell/settings.json"
        printErrors: false
        onLoaded: {
            try {
                root.values = JSON.parse(text()) ?? {};
            } catch (e) {}
            root.finishLoading();
            root.save();
        }
        onLoadFailed: {
            root.finishLoading();
            root.save();
        }
    }
}
