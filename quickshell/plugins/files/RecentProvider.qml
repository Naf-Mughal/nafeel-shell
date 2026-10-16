import QtQuick
import Quickshell
import Nafeel
import qs.components
import qs.services

// Recent files: what you opened lately, then what changed lately. Shown when
// nothing's typed (after the apps you use most), and for "recent: report" /
// "recent report" (fuzzy among them).
LauncherProvider {
    id: root

    name: "Recent"
    icon: "history"
    keyword: "recent"
    prefixes: ["recent"]
    answersEmpty: true
    limit: 8

    readonly property var shared: Plugins.instance("files")
    property int waitingSeq: -1

    function build(text: string): var {
        const out = [];
        const entries = shared.recent;
        const names = entries.map(e => e.path.slice(e.path.lastIndexOf("/") + 1));
        const scores = text === "" ? null : Fuzzy.scores(names, text);
        entries.forEach((e, i) => {
            const s = text === "" ? 50 - i : scores[i];
            if (s <= 0)
                return;
            const r = shared.fileResult(e.path, names[i], s);
            // Used things lead the empty search, recent files follow them,
            // the rest of the apps come after.
            r.idle = 20 - Math.min(i, 15) * 0.5;
            r.subtitle = `${e.why === "opened" ? "Opened" : "Changed"} ${ago(e.t)}   ·   ${r.subtitle}`;
            out.push(r);
        });
        return out;
    }

    function ago(t: real): string {
        const m = Math.round((Date.now() / 1000 - t) / 60);
        return m < 2 ? "just now" : m < 90 ? `${m} min ago` : m < 2880 ? `${Math.round(m / 60)} h ago` : `${Math.round(m / 1440)} days ago`;
    }

    function query(text: string, seq: int): var {
        const f = shared;
        if (!f)
            return [];
        // Typed without its keyword: not this provider's business.
        if (text !== "" && Launcher.scope !== root)
            return [];
        if (f.recentStale)
            f.refreshRecent();
        if (f.recent.length === 0 && f.recentAt === 0) {
            waitingSeq = seq;
            return null;
        }
        return build(text);
    }

    readonly property Connections listed: Connections {
        target: root.shared

        function onRecentListed(): void {
            if (root.waitingSeq >= 0) {
                const s = root.waitingSeq;
                root.waitingSeq = -1;
                root.publish(s, root.build(Launcher.query));
            }
        }
    }
}
