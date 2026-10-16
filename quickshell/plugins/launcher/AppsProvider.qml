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

    function result(app: var, score: real): var {
        return {
            title: app.name,
            subtitle: app.comment || app.genericName || "",
            image: app.icon,
            score: score,
            key: "app:" + app.id,
            run: () => Apps.launch(app),
            actions: (app.actions ?? []).map(a => ({
                        label: a.name,
                        icon: "play_arrow",
                        run: () => a.execute()
                    }))
        };
    }

    function query(text: string, seq: int): var {
        if (text === "")
            return Apps.list.map(a => result(a, 0));
        const out = [];
        for (const a of Apps.list) {
            const s = Math.max(Fuzzy.score(a.name, text), Fuzzy.score(a.genericName ?? "", text) * 0.7, Fuzzy.score((a.keywords ?? []).join(" "), text) * 0.6, Fuzzy.score(a.comment ?? "", text) * 0.45, Fuzzy.score(a.id, text) * 0.5);
            if (s > 0)
                out.push(result(a, s));
        }
        return out;
    }
}
