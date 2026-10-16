import QtQuick
import Quickshell
import Quickshell.Io
import Nafeel
import qs.components
import qs.services

// Emoji and symbols (Unicode CLDR's names and keywords, assets/emoji.json):
// "e smile", "e arrow", "e check". Enter pastes it into the app you came from;
// Tab: copy only. The ones you use most are what the empty search shows.
LauncherProvider {
    id: root

    name: "Emoji"
    icon: "mood"
    keyword: "e"
    global: false
    answersEmpty: true
    limit: 40

    // [character, name, keywords]
    property var all: []
    // name + keywords, for the native scorer.
    property var haystack: []

    readonly property FileView data: FileView {
        path: Quickshell.shellDir + "/assets/emoji.json"
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                root.all = JSON.parse(text());
                root.haystack = root.all.map(e => e[2] ? `${e[1]} ${e[2]}` : e[1]);
            } catch (e) {}
        }
    }

    function result(e: var, s: real): var {
        return {
            title: e[1],
            subtitle: e[2] ? e[2].replace(/ \| /g, ", ") : "",
            glyph: e[0],
            score: s,
            key: "emoji:" + e[0],
            highlight: false,
            run: () => {
                Clipboard.copyText(e[0]);
                Paste.now(false);
            },
            actions: [
                {
                    label: "Copy only",
                    icon: "content_copy",
                    run: () => Clipboard.copyText(e[0])
                }
            ]
        };
    }

    function query(text: string, seq: int): var {
        if (text === "")
            return all.filter(e => Launcher.frecency("emoji:" + e[0]) > 0).map(e => result(e, 0));
        const ns = Fuzzy.scores(haystack, text), titles = Fuzzy.scores(all.map(e => e[1]), text);
        const out = [];
        const words = text.toLowerCase().split(/\s+/).filter(Boolean);
        // What people mean: the word itself in the name or the keywords (a
        // heart is "heart", not letters scattered through "head shaking").
        const wordHits = e => {
            const nameWords = e[1].toLowerCase().split(/[\s,\-:]+/), keyWords = (e[2] ?? "").toLowerCase().split(/ \| /);
            let bonus = 0;
            for (const w of words) {
                if (nameWords.includes(w))
                    bonus += 140;
                else if (keyWords.includes(w))
                    bonus += 90;
                else if (nameWords.some(n => n.startsWith(w)))
                    bonus += 70;
                else if (keyWords.some(k => k.startsWith(w)))
                    bonus += 40;
            }
            return bonus + (e[1].toLowerCase() === text.toLowerCase() ? 80 : 0);
        };
        for (let i = 0; i < ns.length; i++) {
            const s = Math.max(titles[i] * 1.2, ns[i] * 0.8);
            if (s < text.replace(/\s+/g, "").length * 14)
                continue;
            out.push(result(all[i], s + wordHits(all[i])));
        }
        return out;
    }
}
