pragma Singleton

// The wallpaper: which one is set (drawn by modules/background), and the
// library (~/Pictures/Wallpapers, folders as collections) it's picked from.
//
// An ActionService: the picker stages a wallpaper as you choose (its palette
// is made meanwhile), and closing the picker sets it, so the theme changes at
// once, under the shell's ink transition (Theme.go). IPC and keybinds set at
// once (run). `current` follows "wallpaper.current" on the Bus, so it changes
// when the ink lands, with everything else.
//
// The path lives in ~/.local/state/nafeel-shell/wallpaper.json (the first run
// took Noctalia's).
//
// IPC: qs -p <shell> ipc call wallpaper set <path> | random | get

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    // The Settings panel's Wallpaper page.
    readonly property SettingsPage settings: SettingsPage {
        name: "wallpaper"
        title: "Wallpaper"
        gloss: "画卷"
        icon: "wallpaper"
        order: 20
        description: "Live wallpapers and the store."

        SettingItem {
            key: "wallpaper.dir"
            kind: "text"
            icon: "folder"
            section: "Library"
            label: "Folder"
            description: "Where your wallpapers are; its sub-folders are the picker's collections."
            placeholder: "~/Pictures/Wallpapers"
            def: "~/Pictures/Wallpapers"
        }
        SettingItem {
            key: "liveQuality"
            icon: "movie"
            section: "Live wallpapers"
            label: "Resolution"
            description: "Original plays the video file as it is. 1080p or 720p play a copy made at that size (once, in the background): lighter on memory and CPU for 4K videos, a little softer."
            def: "original"
            options: [
                {
                    value: "original",
                    icon: "hd",
                    label: "Original"
                },
                {
                    value: "1080",
                    icon: "high_quality",
                    label: "1080p"
                },
                {
                    value: "720",
                    icon: "sd",
                    label: "720p"
                }
            ]
        }
        SettingItem {
            key: "liveOnBattery"
            icon: "battery_charging_full"
            kind: "toggle"
            label: "Keep playing on battery"
            description: "Off: a live wallpaper holds still while the laptop runs on battery."
            def: true
        }
        SettingItem {
            key: "wallhavenKey"
            icon: "key"
            kind: "text"
            secret: true
            section: "Store"
            label: "Wallhaven API key"
            description: "Optional. Lets the store show sketchy and NSFW results and use your Wallhaven account's settings."
            placeholder: "Paste a key from wallhaven.cc/settings/account"
            def: ""
        }
    }
    readonly property string liveQuality: settings.v.liveQuality

    readonly property string dir: {
        const d = (settings.v["wallpaper.dir"] ?? "").trim() || "~/Pictures/Wallpapers";
        return (d.startsWith("~") ? Quickshell.env("HOME") + d.slice(1) : d).replace(/\/+$/, "");
    }
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/nafeel-shell"
    // The wallpaper as it is now ("" until known).
    property string current: ""
    // What the picker has chosen and will set on close ("" = nothing).
    readonly property string chosen: act.staged?.action === "set" ? (act.staged.args.path ?? act.staged.args) : ""

    // ── Per monitor ──
    // A screen's own wallpaper, over the main one ({ output: path }); none =
    // every screen shows `current`. The main screen (the first) is the one
    // the theme's colours come from, so setting it is setting `current`.
    property var outputs: ({})
    readonly property string mainOutput: Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""
    // The picker's target: "" = every screen, else an output's name.
    property string target: ""

    function wallpaperOf(output: string): string {
        return outputs[output] || current;
    }
    // [{ path, name, folder }]
    property var all: []
    readonly property var folders: [...new Set(all.map(w => w.folder))].sort()

    // The picker's choices: staged, set on close.
    readonly property ActionService act: ActionService {
        name: "wallpaper"
        drawer: "wallpapers"
        // args: a path (every screen), or { path, output }.
        actions: ({
                set: args => {
                    const path = args.path ?? args;
                    const output = args.output ?? "";
                    if (!path)
                        return;
                    if (output && output !== root.mainOutput) {
                        // Another screen's own: its picture changes, the
                        // colours stay with the main one.
                        Theme.goOutput(path, output);
                        return;
                    }
                    // Every screen (or the main one, which the theme follows).
                    if (!output)
                        root._clearOutputs();
                    if (path !== root.current)
                        Theme.go(path);
                }
            })
        prepare: ({
                set: args => {
                    const output = args.output ?? "";
                    if (!output || output === root.mainOutput)
                        Theme.prepare(args.path ?? args);
                }
            })
    }

    function stage(action: string, args: var): void {
        act.stage(action, args);
    }

    // Choose `path` for the picker's target (every screen, or one).
    function choose(path: string): void {
        act.stage("set", target ? {
            path,
            output: target
        } : path);
    }

    function setFor(output: string, path: string): void {
        act.run("set", {
            path,
            output
        });
    }

    function _clearOutputs(): void {
        for (const o of Object.keys(outputs))
            Bus.retain(`wallpaper.output.${o}`, {
                output: o,
                path: ""
            });
        if (Object.keys(outputs).length > 0) {
            outputs = {};
            _save();
        }
    }

    // ── Where the picker looks: your library, or the store (Wallhaven) ──
    property string source: "library"
    // The store's provider: "wallhaven" (pictures) | "motionbgs" (live).
    property string provider: "wallhaven"
    // The stores are the wallpaper studio plugin's (none while it's off).
    readonly property var studio: Plugins.instance("wallpaper")
    readonly property var store: studio ? (provider === "motionbgs" ? studio.motionbgs : studio.wallhaven) : null

    function useProvider(name: string): void {
        provider = name === "motionbgs" ? "motionbgs" : "wallhaven";
        if (store && !store.started)
            store.search();
    }

    // A wallpaper's picture for a card: the library's thumbnail, a store
    // result's preview, or the file.
    function picture(w: var): string {
        if (!w)
            return "";
        if (w.thumbUrl)
            return w.thumbUrl;
        if (w.thumb)
            return "file://" + w.thumb;
        return w.path ? "file://" + w.path : "";
    }

    // Choose a store result: download it, then it's chosen like any other
    // (set when the picker closes, or at once if it closed meanwhile).
    property string fetching: ""
    function fetch(item: var): void {
        if (!studio)
            return;
        fetching = item.id;
        if (item.provider === "motionbgs")
            studio.motionbgs.download(item);
        else
            studio.wallhaven.download(item);
    }

    Connections {
        target: Bus

        function onPublished(topic: string, payload: var): void {
            if (topic !== "store.downloaded")
                return;
            root.rescan();
            if (payload.id !== root.fetching)
                return;
            root.fetching = "";
            if (root.act._open)
                root.choose(payload.path);
            else if (root.target)
                root.setFor(root.target, payload.path);
            else
                root.set(payload.path);
        }
    }

    // ── Live wallpapers ──
    function isVideo(path: string): bool {
        return /\.(mp4|webm|mkv|mov|m4v)$/i.test(path ?? "");
    }

    // A picture of `path` for places that show the wallpaper as an image (the
    // home tab, workspaces): itself, or a video's indexed frame.
    function stillOf(path: string): string {
        if (!isVideo(path))
            return path;
        return all.find(w => w.path === path)?.thumb ?? "";
    }

    // What plays for a live wallpaper: the file (resolution "original"), or
    // the indexer's copy at 1080p / 720p once it exists.
    function playOf(path: string): string {
        if (liveQuality === "original" || !isVideo(path))
            return path;
        const live = all.find(w => w.path === path)?.live ?? "";
        return live.includes(`-${liveQuality}.`) ? live : path;
    }


    // The setting changed: make (or drop) the copies.
    onLiveQualityChanged: _index()
    onDirChanged: _index()


    function inFolder(folder: string): var {
        return folder ? all.filter(w => w.folder === folder) : all;
    }

    // Set at once (IPC, keybinds, a click outside the picker).
    function set(path: string): void {
        act.run("set", path);
    }

    // Any other wallpaper, from the whole library, at once.
    function random(): void {
        const others = all.filter(w => w.path !== current);
        if (others.length > 0)
            set(others[Math.floor(Math.random() * others.length)].path);
    }

    function rescan(): void {
        scan.running = true;
    }

    function _remember(path: string): void {
        current = path;
        _save();
    }

    function _save(): void {
        stateFile.setText(JSON.stringify({
            path: current,
            outputs
        }, null, 2) + "\n");
    }

    // The ink landed (Theme): it's the wallpaper now.
    Connections {
        target: Bus

        function onPublished(topic: string, payload: var): void {
            if (topic === "wallpaper.current" && payload.path && payload.path !== root.current)
                root._remember(payload.path);
            else if (topic.startsWith("wallpaper.output.") && payload.output && payload.path) {
                const o = Object.assign({}, root.outputs);
                o[payload.output] = payload.path;
                root.outputs = o;
                root._save();
            }
        }
    }

    IpcHandler {
        target: "wallpaper"

        function set(path: string): void {
            root.set(path);
        }
        function random(): void {
            root.random();
        }
        function get(): string {
            return root.current;
        }
        // One screen's own wallpaper (another screen than the main one keeps
        // the colours as they are).
        function setFor(output: string, path: string): void {
            root.setFor(output, path);
        }
        // Where the picker looks: library | store.
        function source(name: string): void {
            // library | store (Wallhaven) | live (motionbgs)
            root.source = name === "library" ? "library" : "store";
            if (root.source === "store")
                root.useProvider(name === "live" ? "motionbgs" : "wallhaven");
        }
        // Move the open picker's selection by n (keybinds; tests).
        function step(n: int): void {
            Bus.publish("picker.step", {
                n
            });
        }
        // The picker's view: slice | strip | mosaic.
        function view(name: string): void {
            root.view = name;
        }
    }

    FileView {
        id: stateFile

        path: root.stateDir + "/wallpaper.json"
        printErrors: false
        onLoaded: {
            try {
                const st = JSON.parse(text());
                const p = st.path ?? "";
                root.outputs = st.outputs ?? {};
                for (const [o, op] of Object.entries(root.outputs))
                    Bus.retain(`wallpaper.output.${o}`, {
                        output: o,
                        path: op
                    });
                if (p)
                    root.current = p;
                // Others (Background) start from the remembered one.
                if (p)
                    Bus.retain("wallpaper.current", {
                        path: p
                    });
                else
                    adopt.running = true;
            } catch (e) {
                adopt.running = true;
            }
        }
        onLoadFailed: adopt.running = true
    }

    // First run: carry over Noctalia's wallpaper.
    Process {
        id: adopt

        command: ["sh", "-c", 'mkdir -p "$1"; noctalia msg wallpaper-get', "sh", root.stateDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                if (p && !p.startsWith("error")) {
                    root._remember(p);
                    Bus.retain("wallpaper.current", {
                        path: p
                    });
                }
            }
        }
    }

    // ── The library ─────────────────────────────────────────────────────
    // The index (bin/nafeel-theme index -> theme/palette/library.py, after
    // Ryoku's indexing daemon): every wallpaper with a thumbnail and its
    // colour. A quick `find` fills `all` first so the picker never waits; the
    // index then adds thumbnails and colours, and new files get indexed in
    // the background (progress: Bus "library.progress" { done, total }).

    readonly property string indexPath: Quickshell.env("HOME") + "/.cache/nafeel-shell/library.json"
    readonly property string bin: Quickshell.shellDir + "/../bin/nafeel-theme"
    property bool indexing: indexer.running
    property real indexProgress: 1

    // Filters for the picker (all optional): folder, colour bucket (0..11 hue
    // in 30° steps from red, 99 black and white, -1 any), tone ("dark" |
    // "light" | ""), favourites only, and a search.
    property string filterFolder: ""
    property int filterColour: -1
    property string filterTone: ""
    property bool filterFavourites: false
    property string query: ""
    // "name" | "colour" | "recent" | "used"
    property string sortMode: "name"
    // The picker's view: "slice" | "strip" | "mosaic".
    property string view: "slice"
    onSortModeChanged: _saveMeta()
    onViewChanged: _saveMeta()
    property var favourites: ({})
    property var useCount: ({})

    readonly property var shown: {
        const q = query.trim().toLowerCase();
        let list = all.filter(w => (!filterFolder || w.folder === filterFolder) && (filterColour < 0 || w.bucket === filterColour) && (!filterTone || (filterTone === "dark" ? (w.lightness ?? 0.5) < 0.42 : (w.lightness ?? 0.5) >= 0.55)) && (!filterFavourites || favourites[w.path]) && (!q || w.name.toLowerCase().includes(q) || w.folder.toLowerCase().includes(q)));
        const byName = (a, b) => a.path < b.path ? -1 : a.path > b.path ? 1 : 0;
        switch (sortMode) {
        case "colour":
            // Round the colour wheel, vivid first in each hue; black and white last.
            list = list.slice().sort((a, b) => ((a.bucket ?? 99) - (b.bucket ?? 99)) || ((b.chroma ?? 0) - (a.chroma ?? 0)) || byName(a, b));
            break;
        case "recent":
            list = list.slice().sort((a, b) => (b.mtime ?? 0) - (a.mtime ?? 0));
            break;
        case "used":
            list = list.slice().sort((a, b) => (useCount[b.path] ?? 0) - (useCount[a.path] ?? 0) || byName(a, b));
            break;
        }
        return list;
    }

    function toggleFavourite(path: string): void {
        const f = Object.assign({}, favourites);
        if (f[path])
            delete f[path];
        else
            f[path] = true;
        favourites = f;
        _saveMeta();
    }

    function clearFilters(): void {
        filterFolder = "";
        filterColour = -1;
        filterTone = "";
        filterFavourites = false;
        query = "";
    }

    function _saveMeta(): void {
        if (!metaLoaded)
            return;
        metaFile.setText(JSON.stringify({
            favourites,
            useCount,
            view,
            sortMode
        }, null, 2) + "\n");
    }

    function _index(): void {
        if (!indexer.running)
            indexer.running = true;
    }

    property bool metaLoaded: false

    // Favourites, how often each was set (Ryoku's "apply count"), the view.
    FileView {
        id: metaFile

        path: root.stateDir + "/wallpaper-library.json"
        printErrors: false
        onLoaded: {
            try {
                const m = JSON.parse(text());
                root.favourites = m.favourites ?? {};
                root.useCount = m.useCount ?? {};
                root.view = ["slice", "strip", "mosaic"].includes(m.view) ? m.view : root.view;
                root.sortMode = m.sortMode ?? root.sortMode;
            } catch (e) {}
            root.metaLoaded = true;
        }
        onLoadFailed: root.metaLoaded = true
    }

    Connections {
        target: Bus

        function onPublished(topic: string, payload: var): void {
            if (topic !== "wallpaper.current" || !payload.path)
                return;
            const u = Object.assign({}, root.useCount);
            u[payload.path] = (u[payload.path] ?? 0) + 1;
            root.useCount = u;
            root._saveMeta();
        }
    }

    FileView {
        id: indexFile

        path: root.indexPath
        printErrors: false
        // Written by the indexer, which may run outside the shell too.
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const idx = JSON.parse(text());
                const byPath = {};
                for (const w of idx.wallpapers ?? [])
                    byPath[w.path] = w;
                // Keep files the index hasn't reached yet (new ones).
                const merged = root.all.map(w => byPath[w.path] ?? w);
                const have = new Set(merged.map(w => w.path));
                for (const w of idx.wallpapers ?? [])
                    if (!have.has(w.path))
                        merged.push(w);
                root.all = merged.sort((a, b) => a.path < b.path ? -1 : 1);
            } catch (e) {
                console.warn("wallpapers: bad library index:", e);
            }
        }
    }

    Process {
        id: indexer

        command: [root.bin, "index"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const p = JSON.parse(line);
                    if (p.total) {
                        root.indexProgress = p.done / p.total;
                        Bus.publish("library.progress", p);
                    }
                } catch (e) {}
            }
        }
        onExited: {
            root.indexProgress = 1;
            indexFile.reload();
            Bus.publish("library.updated", {
                count: root.all.length
            });
        }
    }

    Process {
        id: scan

        running: true
        command: ["find", root.dir, "-type", "f", "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", "-o", "-iname", "*.mp4", "-o", "-iname", "*.webm", "-o", "-iname", "*.mkv", "-o", "-iname", "*.mov", "-o", "-iname", "*.m4v", ")"]
        stdout: StdioCollector {
            onStreamFinished: {
                const known = {};
                for (const w of root.all)
                    known[w.path] = w;
                root.all = text.split("\n").filter(p => p && !p.includes("/.")).sort().map(p => {
                    if (known[p])
                        return known[p];
                    const rel = p.slice(root.dir.length + 1);
                    const parts = rel.split("/");
                    return {
                        path: p,
                        name: parts[parts.length - 1],
                        folder: parts.length > 1 ? parts[0] : ""
                    };
                });
                indexFile.reload();
                // New or changed files get thumbnails and colours.
                root._index();
            }
        }
    }
}
