import QtQuick
import Quickshell
import Nafeel
import qs.components
import qs.services

// Installed apps: by name first, then what they're for (generic name,
// keywords, the description), so "browser" or "pdf" finds them too. With
// nothing typed, all of them, the most used on top.
LauncherProvider {
    name: "Apps"
    keyword: "a"
    weight: 1
    limit: 40
    answersEmpty: true

    // An app that's running goes to its window (the most recently used one,
    // on whichever workspace it is) rather than starting another; "New
    // window" is its first action.
    function result(app: var, score: real, open: var): var {
        const running = open[app.id] ?? [];
        return {
            title: app.name,
            subtitle: running.length > 0 ? `Running${running.length > 1 ? " · " + running.length + " windows" : ""}   ·   Enter goes to it` : app.comment || app.genericName || "",
            image: app.icon,
            score: score,
            key: "app:" + app.id,
            run: () => running.length > 0 ? Umbriel.focusWindow(running[0]) : Apps.launch(app),
            actions: (running.length > 0 ? [
                    {
                        label: "New window",
                        icon: "open_in_new",
                        run: () => Apps.launch(app)
                    }
                ] : []).concat((app.actions ?? []).map(a => ({
                            label: a.name,
                            icon: "play_arrow",
                            run: () => a.execute()
                        })))
        };
    }

    // Open windows by app id, the most recently used first.
    function windowsByApp(): var {
        const by = {};
        const order = Umbriel.mru;
        const sorted = Umbriel.windows.slice().sort((a, b) => (order.indexOf(a.id) + 1 || 1e9) - (order.indexOf(b.id) + 1 || 1e9));
        for (const w of sorted) {
            const id = Apps.forAppId(w.app_id)?.id;
            if (id)
                (by[id] = by[id] ?? []).push(w);
        }
        return by;
    }

    function query(text: string, seq: int): var {
        const open = windowsByApp();
        if (text === "")
            return Apps.list.map(a => result(a, 0, open));
        const out = [];
        for (const a of Apps.list) {
            const s = Math.max(Fuzzy.score(a.name, text), Fuzzy.score(a.genericName ?? "", text) * 0.7, Fuzzy.score((a.keywords ?? []).join(" "), text) * 0.6, Fuzzy.score(a.comment ?? "", text) * 0.45, Fuzzy.score(a.id, text) * 0.5);
            if (s > 0)
                out.push(result(a, s, open));
        }
        return out;
    }
}
