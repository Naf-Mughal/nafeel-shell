pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The launcher: the command center's search, answered by the providers the
// plugins declare (Plugins.providers, each a LauncherProvider). A query goes
// to every global provider, or only to the one whose keyword it starts with
// ("f report": files; "> ls", "= 2+2": no space after a symbol). Results are
// merged and ranked by match (the provider's score times its weight) and by
// use: what's picked often and lately rises (frecency, kept in
// ~/.local/state/nafeel-shell/launcher.json).
Singleton {
    id: root

    // What's typed (the command center's search).
    property string text: ""
    property int selected: 0

    // The providers made from the enabled plugins' declarations.
    property var providers: []

    // The query after any keyword, and the provider it's scoped to (null:
    // every global one).
    readonly property var scope: parse(text, providers).scope
    readonly property string query: parse(text, providers).query

    // (A function, not those bindings, for refresh(): it runs on the text's
    // change before bindings over the text have caught up.)
    function parse(t: string, list: var): var {
        for (const p of list) {
            const k = p.keyword;
            if (!k)
                continue;
            if (/^[A-Za-z0-9]+$/.test(k) ? t.startsWith(k + " ") : t.startsWith(k))
                return { scope: p, query: t.slice(k.length).trim() };
        }
        return { scope: null, query: t.trim() };
    }

    // Every provider's latest answer: { providerIndex: results }.
    property var answers: ({})
    property int seq: 0

    readonly property var results: {
        const out = [];
        const empty = query === "";
        providers.forEach((p, i) => {
            const list = answers[i];
            if (!list)
                return;
            for (const r of list.slice(0, p.limit)) {
                const use = frecency(r.key);
                out.push(Object.assign({}, r, {
                    provider: p.name,
                    // `top`: what was asked for outright (a typed URL, a web
                    // keyword): above any fuzzy match.
                    rank: empty ? use : r.top ? 1000 + (r.score ?? 0) : (r.score ?? 0) * p.weight + use
                }));
            }
        });
        out.sort((a, b) => b.rank - a.rank || (a.title ?? "").localeCompare(b.title ?? ""));
        // The same thing twice (two settings with one label on one page):
        // once.
        const seen = new Set();
        for (let i = out.length - 1; i >= 0; i--) {
            const id = `${out[i].provider}|${out[i].title}|${out[i].subtitle ?? ""}`;
            if (seen.has(id))
                out.splice(i, 1);
            seen.add(id);
        }
        // Typed: what matches far worse than the best is noise ("shut" also
        // scattering into "LibreOffice Draw").
        if (!empty && out.length > 0) {
            const floor = out[0].rank * 0.3;
            return out.filter(r => r.rank >= floor).slice(0, 60);
        }
        return out.slice(0, 60);
    }

    readonly property var current: results[Math.min(selected, results.length - 1)] ?? null

    // Tab on a result with actions lists them here; Esc / Shift+Tab goes
    // back.
    property var actionsOf: null
    property int actionSelected: 0
    // A result asking to be confirmed (its `confirm`) by a second Enter.
    property string confirming: ""

    onTextChanged: refresh()
    onProvidersChanged: refresh()

    function refresh(): void {
        selected = 0;
        actionsOf = null;
        confirming = "";
        const s = ++seq;
        const next = {};
        const { scope, query } = parse(text, providers);
        providers.forEach((p, i) => {
            const asked = scope ? scope === p : p.global;
            if (!asked || (query === "" && !scope && !p.answersEmpty))
                return;
            const r = p.query(query, s);
            if (r)
                next[i] = r;
            else if (answers[i] && p.keepStale)
                next[i] = answers[i]; // asynchronous: the last answer stays until the new one
        });
        answers = next;
    }

    function accept(provider: var, s: int, list: var): void {
        if (s !== seq)
            return;
        const i = providers.indexOf(provider);
        if (i < 0)
            return;
        const next = Object.assign({}, answers);
        next[i] = list ?? [];
        answers = next;
    }

    function move(by: int): void {
        if (actionsOf) {
            const n = actionsOf.actions.length;
            actionSelected = (actionSelected + by + n) % n;
            return;
        }
        if (results.length > 0)
            selected = (selected + by + results.length) % results.length;
        confirming = "";
    }

    // Enter: the selected result (or action); `alternate` (Shift+Enter): its
    // first action.
    function activate(alternate: bool): void {
        if (actionsOf) {
            const a = actionsOf.actions[actionSelected];
            if (a)
                finish(actionsOf, () => a.run());
            return;
        }
        const r = current;
        if (!r)
            return;
        if (alternate && r.actions?.length) {
            finish(r, () => r.actions[0].run());
            return;
        }
        if (r.confirm && confirming !== (r.key ?? r.title)) {
            confirming = r.key ?? r.title;
            return;
        }
        finish(r, () => r.run?.());
    }

    function showActions(): bool {
        if (actionsOf || !current?.actions?.length)
            return false;
        actionsOf = current;
        actionSelected = 0;
        return true;
    }

    function hideActions(): bool {
        if (!actionsOf)
            return false;
        actionsOf = null;
        return true;
    }

    function finish(r: var, run: var): void {
        if (r.key)
            use(r.key);
        const keep = r.keepOpen === true;
        if (!keep) {
            ShellState.ccQuery = "";
            ShellState.close();
        }
        run();
    }

    // ── Frecency ──
    // Picks per key: { c: count, t: last (ms) }. The boost: more for more
    // picks, faded by how long ago the last was.
    property var uses: ({})

    function frecency(key: string): real {
        const u = key ? uses[key] : null;
        if (!u)
            return 0;
        const days = (Date.now() - u.t) / 86400000;
        const fade = days < 1 ? 1 : days < 7 ? 0.7 : days < 30 ? 0.45 : 0.25;
        return 28 * Math.log2(1 + u.c) * fade;
    }

    function use(key: string): void {
        const next = Object.assign({}, uses);
        const u = next[key] ?? { c: 0, t: 0 };
        next[key] = { c: u.c + 1, t: Date.now() };
        uses = next;
        saveUses.restart();
    }

    Timer {
        id: saveUses

        interval: 1000
        onTriggered: usesFile.setText(JSON.stringify({ uses: root.uses }) + "\n")
    }

    FileView {
        id: usesFile

        path: Quickshell.env("HOME") + "/.local/state/nafeel-shell/launcher.json"
        printErrors: false
        onLoaded: {
            try {
                root.uses = JSON.parse(text()).uses ?? {};
            } catch (e) {}
        }
    }

    // qs ipc call launcher query <text>: the top results as JSON (testing;
    // asynchronous providers answer a moment later: query again).
    IpcHandler {
        target: "launcher"

        function query(text: string): string {
            root.text = text;
            return JSON.stringify(root.results.slice(0, 12).map(r => [r.provider, r.title, Math.round(r.rank)]));
        }
        function providers(): string {
            return JSON.stringify(root.providers.map(p => [p.name, p.keyword, p.global]));
        }
    }

    // ── The providers ──
    Instantiator {
        id: made

        model: Plugins.providers

        delegate: Loader {
            required property var modelData

            source: modelData.url
            asynchronous: true
            onLoaded: root.collect()
        }

        onObjectRemoved: Qt.callLater(root.collect)
    }

    // The loaded providers, in the plugins' order; each one's answers that
    // come later (publish) reach accept().
    property var _wired: []
    function collect(): void {
        const list = [];
        for (let i = 0; i < made.count; i++) {
            const p = made.objectAt(i)?.item;
            if (!p)
                continue;
            list.push(p);
            if (!_wired.includes(p)) {
                _wired.push(p);
                p.published.connect((s, r) => root.accept(p, s, r));
            }
        }
        _wired = _wired.filter(p => list.includes(p));
        providers = list;
    }
}
