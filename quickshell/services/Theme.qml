pragma Singleton

// The theme, conducted: the palette is made ahead (while the wallpaper picker
// is still open, `nafeel-theme update --stage`), the wallpaper is decoded
// ahead, and then one shell-wide ink transition (Ink) changes it all
// at once: the shell's colours and the wallpaper under the ink, the apps
// (`nafeel-theme commit`: templates, open terminals) as it soaks through.
//
//   Theme.prepare(path)        get ready for a wallpaper (staged in the picker)
//   Theme.go(path)             change to it (the picker closed, IPC, random)
//   Theme.refresh()            settings changed (paper, radius): rebuild, no ink
//
// Bus: "theme.ready" { path } (staged), "theme.changed" { doc } (retained:
// the current theme document), "wallpaper.preload" { path } (Background
// decodes it, answers "wallpaper.loaded"), "wallpaper.current" { path }.
//
// IPC: qs -p <shell> ipc call theme update | force

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    // The Settings panel's Theme page (bin/nafeel-theme reads these from
    // settings.json over its theme.toml; the template lists stay there).
    readonly property SettingsPage settings: SettingsPage {
        name: "theme"
        title: "Theme"
        gloss: "色彩"
        icon: "format_paint"
        order: 15
        description: "The colours taken from the wallpaper, and the apps that follow them."

        SettingItem {
            key: "theme.mode"
            label: "Mode"
            description: "Auto: light from sunrise to sunset (the weather's), dark after."
            def: "dark"
            options: [
                {
                    value: "dark",
                    icon: "dark_mode",
                    label: "Dark"
                },
                {
                    value: "light",
                    icon: "light_mode",
                    label: "Light"
                },
                {
                    value: "auto",
                    icon: "routine",
                    label: "Auto"
                }
            ]
        }
        SettingItem {
            key: "theme.variant"
            label: "Palette"
            description: "How colours are drawn from the wallpaper: the pigment styles keep to its real colours as ink-wash and paper tones; the Material schemes build a full M3 palette from one seed."
            def: "pigment"
            options: [
                {
                    value: "pigment",
                    icon: "brush",
                    label: "Pigment"
                },
                {
                    value: "pigment-soft",
                    icon: "water_drop",
                    label: "Pigment soft"
                },
                {
                    value: "pigment-vibrant",
                    icon: "colors",
                    label: "Pigment vibrant"
                },
                {
                    value: "pigment-expressive",
                    icon: "palette",
                    label: "Pigment expressive"
                },
                {
                    value: "pigment-fruitsalad",
                    icon: "nutrition",
                    label: "Pigment fruit salad"
                },
                {
                    value: "auto",
                    icon: "auto_awesome",
                    label: "Material: auto"
                },
                {
                    value: "tonalspot",
                    icon: "tonality",
                    label: "Tonal spot"
                },
                {
                    value: "vibrant",
                    icon: "colorize",
                    label: "Vibrant"
                },
                {
                    value: "expressive",
                    icon: "format_paint",
                    label: "Expressive"
                },
                {
                    value: "fidelity",
                    icon: "photo",
                    label: "Fidelity"
                },
                {
                    value: "content",
                    icon: "image",
                    label: "Content"
                },
                {
                    value: "fruitsalad",
                    icon: "emoji_food_beverage",
                    label: "Fruit salad"
                },
                {
                    value: "rainbow",
                    icon: "looks",
                    label: "Rainbow"
                },
                {
                    value: "neutral",
                    icon: "contrast",
                    label: "Neutral"
                },
                {
                    value: "monochrome",
                    icon: "filter_b_and_w",
                    label: "Monochrome"
                }
            ]
        }
        SettingItem {
            key: "theme.contrast"
            kind: "number"
            label: "Contrast"
            description: "Below 0 softer, above 0 crisper (Material contrast level)."
            def: 0
            min: -1
            max: 1
            step: 0.1
        }
        SettingItem {
            key: "theme.flavour"
            label: "Terminal colours"
            def: "default"
            options: [
                {
                    value: "default",
                    icon: "terminal",
                    label: "Default"
                },
                {
                    value: "hard",
                    icon: "contrast",
                    label: "Hard"
                }
            ]
        }
        SettingItem {
            key: "theme.apps"
            kind: "toggle"
            icon: "apps"
            section: "Apps"
            label: "Theme apps"
            description: "Third-party apps follow the palette (the desktop itself always does)."
            def: true
        }
        SettingItem {
            key: "theme.appOpacity"
            kind: "number"
            label: "App opacity"
            description: "Terminals (foot, kitty, alacritty) over the compositor's blur; 100% is solid."
            def: 78
            min: 30
            max: 100
            step: 1
            unit: "%"
        }
        SettingItem {
            key: "theme.gtkTranslucent"
            kind: "toggle"
            icon: "web_asset"
            label: "Translucent GTK apps"
            description: "GTK windows take the app opacity too (some apps draw oddly translucent)."
            def: false
        }
        SettingItem {
            key: "theme.core"
            kind: "multi"
            label: "Built-in templates"
            description: "The desktop and the apps themed from the shell's palette."
            def: root.known.core ?? []
            options: (root.known.builtin ?? []).map(t => ({
                        value: t.id,
                        icon: "brush",
                        label: t.name
                    }))
        }
        SettingItem {
            key: "theme.community"
            kind: "multi"
            label: "Community templates"
            description: "From Noctalia's catalog: downloaded (checksums checked) when first chosen. Some run their own script after rendering."
            def: root.known.community ?? []
            options: root.catalog.map(t => ({
                        value: t.id,
                        icon: t.installed ? "download_done" : "download",
                        label: t.id
                    }))
            shown: root.settings.v["theme.apps"] === true
        }
        SettingItem {
            key: "theme.liveTerminals"
            kind: "toggle"
            icon: "terminal"
            label: "Recolour open terminals"
            description: "Running terminals change colour at once, not only new ones."
            def: true
        }
    }

    readonly property string bin: Quickshell.shellDir + "/../bin/nafeel-theme"
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/nafeel-shell"

    // The wallpaper whose theme is staged (theme-next.json), and the one
    // being staged now.
    property string stagedPath: ""
    property string stagingPath: ""
    // The staged document, as the stage printed it (its .wallpaper says
    // which wallpaper it is for).
    property var stagedDoc: null
    // A change waiting on staging / decoding: { path, staged, loaded }.
    property var pending: null
    // The last apply's report (one line per template).
    property string report: ""

    function prepare(path: string): void {
        if (!path || path === stagedPath || path === stagingPath)
            return;
        if (stage.running) {
            // The latest pick wins; it's staged once this run ends.
            nextStage = path;
            return;
        }
        stagingPath = path;
        stage.command = [bin, "update", "--stage", "--wallpaper", path];
        stage.running = true;
    }

    property string nextStage: ""

    function go(path: string): void {
        if (!path)
            return;
        pending = {
            path,
            staged: path === stagedPath,
            loaded: false
        };
        if (!pending.staged)
            prepare(path);
        Bus.publish("wallpaper.preload", {
            path
        });
        giveUp.restart();
    }

    // Another screen's own wallpaper: decoded there, then the ink; the
    // colours stay with the main screen's.
    property var pendingOutput: null
    function goOutput(path: string, output: string): void {
        pendingOutput = {
            path,
            output
        };
        Bus.publish("wallpaper.preload", {
            path,
            output
        });
        outputGiveUp.restart();
    }

    function _outputGo(): void {
        const p = pendingOutput;
        if (!p)
            return;
        pendingOutput = null;
        outputGiveUp.stop();
        Ink.ink(() => Bus.retain(`wallpaper.output.${p.output}`, p), Qt.point(0.5, 0.5));
    }

    Timer {
        id: outputGiveUp

        interval: 8000
        onTriggered: root._outputGo()
    }

    function refresh(): void {
        if (!apply.running) {
            apply.command = [bin, "update"];
            apply.running = true;
        } else {
            refreshAgain = true;
        }
    }

    property bool refreshAgain: false
    // A staged theme whose apps still wait for the ink to get far enough.
    property bool appsOwed: false

    Connections {
        target: Ink

        function onProgressChanged(): void {
            if (root.appsOwed && Ink.frozen && Ink.progress >= 0.55)
                root._commitApps();
        }
        function onFrozenChanged(): void {
            // No ink (reduced motion) or it ended early: don't leave them.
            if (root.appsOwed && !Ink.frozen)
                root._commitApps();
        }
    }

    function _commitApps(): void {
        appsOwed = false;
        commit.running = true;
    }

    function _maybeGo(): void {
        const p = pending;
        if (!p || !p.staged || !p.loaded)
            return;
        pending = null;
        giveUp.stop();
        // Only this wallpaper's document; anything else waits for the commit
        // (which reloads theme.json) rather than showing the wrong colours.
        const doc = stagedDoc && stagedDoc.wallpaper === p.path ? stagedDoc : null;
        Ink.ink(() => {
            if (doc)
                Colours.load(doc);
            Bus.retain("wallpaper.current", {
                path: p.path
            });
        }, Qt.point(0.5, 0.5));
        // The apps follow the ink: their templates start rendering halfway
        // through (about as long as the rest of the soak), so terminals,
        // GTK, Qt and the compositor land as the shell does.
        appsOwed = true;
        // Reduced motion: no ink ran, the change already happened.
        if (!Ink.frozen && !Ink.capturing)
            _commitApps();
    }

    function _parse(text: string): var {
        try {
            return JSON.parse(text);
        } catch (e) {
            return null;
        }
    }

    IpcHandler {
        target: "theme"

        function update(): void {
            root.refresh();
        }
        // What the shell is showing: "<primary> <surface> <mode> <wallpaper>".
        function state(): string {
            return `${Colours.palette.m3primary} ${Colours.palette.m3surface} ${Colours.theme?.mode} ${Colours.theme?.wallpaper}`;
        }
        function force(): void {
            apply.command = [root.bin, "update", "--force"];
            apply.running = true;
        }
    }

    // Staged and decoded never both arrive (a broken file, a failed palette):
    // change anyway, with what there is.
    Timer {
        id: giveUp

        interval: 8000
        onTriggered: {
            if (!root.pending)
                return;
            console.warn("theme: change to", root.pending.path, "went ahead without", root.pending.staged ? "the decoded wallpaper" : "its palette");
            root.pending = Object.assign({}, root.pending, {
                staged: true,
                loaded: true
            });
            root._maybeGo();
        }
    }

    Connections {
        target: Bus

        function onPublished(topic: string, payload: var): void {
            if (topic === "wallpaper.loaded" && root.pendingOutput && payload.path === root.pendingOutput.path && payload.output === root.pendingOutput.output) {
                root._outputGo();
                return;
            }
            if (topic === "wallpaper.loaded" && root.pending && payload.path === root.pending.path) {
                root.pending = Object.assign({}, root.pending, {
                    loaded: true
                });
                root._maybeGo();
            }
        }
    }

    Process {
        id: stage

        stdout: StdioCollector {
            onStreamFinished: {
                const doc = root._parse(text.trim());
                if (doc?.wallpaper)
                    root.stagedDoc = doc;
            }
        }
        stderr: SplitParser {
            onRead: line => console.log("theme:", line)
        }
        onExited: code => {
            const path = root.stagingPath;
            root.stagingPath = "";
            if (code === 0 && root.stagedDoc?.wallpaper === path) {
                root.stagedPath = path;
                Bus.publish("theme.ready", {
                    path
                });
                if (root.pending && root.pending.path === path) {
                    root.pending = Object.assign({}, root.pending, {
                        staged: true
                    });
                    root._maybeGo();
                }
            }
            if (root.nextStage) {
                const n = root.nextStage;
                root.nextStage = "";
                root.prepare(n);
            }
        }
    }

    Process {
        id: commit

        command: [root.bin, "commit"]
        stdout: StdioCollector {
            onStreamFinished: root.report = text
        }
        stderr: SplitParser {
            onRead: line => console.log("theme:", line)
        }
        onExited: {
            root.stagedPath = "";
            root.stagedDoc = null;
            // Whatever happened on the way, end on the theme the apps got.
            current.reload();
        }
    }

    // A rebuild without a change of wallpaper (settings), or the first run.
    Process {
        id: apply

        stdout: StdioCollector {
            onStreamFinished: root.report = text
        }
        stderr: SplitParser {
            onRead: line => console.log("theme:", line)
        }
        onExited: {
            current.reload();
            if (root.refreshAgain) {
                root.refreshAgain = false;
                root.refresh();
            }
        }
    }

    // The current theme document, published for whoever follows it.
    FileView {
        id: current

        // The colours last shown: unchanged ones need no ink.
        property string lastText: ""

        path: `${root.stateDir}/theme.json`
        printErrors: false
        onLoaded: {
            const doc = root._parse(text());
            if (!doc)
                return;
            // Only a change of colours (or mode) is worth the ink.
            const look = JSON.stringify([doc.mode, doc.dark, doc.light]);
            const same = look === lastText;
            lastText = look;
            if (root.inkNext && !same) {
                root.inkNext = false;
                Ink.ink(() => Colours.load(doc), Qt.point(0.5, 0.5));
            } else {
                root.inkNext = false;
                Colours.load(doc);
            }
            Bus.retain("theme.changed", {
                doc
            });
        }
    }

    // What the engine knows: { builtin: [{ id, name, category }], core,
    // community } (the current lists, the defaults until set here), and the
    // community catalog [{ id, category, installed }].
    property var known: ({})
    property var catalog: []

    Process {
        running: true
        command: [root.bin, "list", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.known = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    Process {
        id: catalogLoader

        running: true
        command: [root.bin, "catalog"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.catalog = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    // Auto mode: rebuilt when the day turns (sunrise, sunset; checked each
    // minute).
    property bool isDay: true

    function _day(): bool {
        const now = new Date();
        const today = Weather.days?.[0];
        if (today?.sunrise_iso && today?.sunset_iso) {
            const up = new Date(today.sunrise_iso), down = new Date(today.sunset_iso);
            if (!isNaN(up) && !isNaN(down) && up.toDateString() === now.toDateString())
                return now >= up && now < down;
        }
        const h = now.getHours();
        return h >= 7 && h < 19;
    }

    Timer {
        running: root.settings.v["theme.mode"] === "auto"
        repeat: true
        interval: 60000
        triggeredOnStart: true
        onTriggered: {
            const day = root._day();
            if (day !== root.isDay) {
                root.isDay = day;
                root.inkNext = true;
                root.refresh();
            }
        }
    }

    // A change made here (mode, palette, contrast…) soaks in under the ink,
    // as a wallpaper change does; the first load and wallpaper commits don't.
    property bool inkNext: false

    // The apps' templates carry the paper's opacity, the corner radius and
    // the Theme page's choices: rebuilt when any of them changes.
    // (What's stored, not the defaults: those arrive as the engine answers.)
    readonly property string look: {
        const v = Settings.values;
        return JSON.stringify(Object.keys(v).filter(k => k.startsWith("theme.") || k === "paper" || k === "radius").sort().map(k => [k, v[k]]));
    }

    onLookChanged: {
        if (Settings.loaded) {
            inkNext = true;
            refresh();
            // A community template just chosen is downloaded by the update:
            // the catalog then shows it installed.
            catalogRefresh.restart();
        }
    }

    Timer {
        id: catalogRefresh

        interval: 15000
        onTriggered: catalogLoader.running = true
    }
}
