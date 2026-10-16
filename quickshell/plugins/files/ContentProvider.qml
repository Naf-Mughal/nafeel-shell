import QtQuick
import Quickshell
import Quickshell.Io
import Nafeel
import qs.components
import qs.services

// The text inside files: ripgrep over the folders (and the document index),
// live as you type (after a short pause). The longest word is searched; a
// line counts when all the words are on it, in any order, fuzzily; each file
// shows its best line. PDFs and office documents are found through their
// extracted text (index-docs.py).
LauncherProvider {
    id: root

    name: "Text"
    icon: "manage_search"
    keyword: "t"
    weight: 0.6
    limit: 12

    readonly property var shared: Plugins.instance("files")

    property string asked: ""
    property int askedSeq: -1

    function query(text: string, seq: int): var {
        const f = shared;
        if (!f || !f.contentOn)
            return [];
        if (text.length < (Launcher.scope === root ? 2 : 3)) {
            rg.running = false;
            return [];
        }
        asked = text;
        askedSeq = seq;
        pause.restart();
        return null;
    }

    readonly property Timer pauser: Timer {
        id: pause

        interval: 220
        onTriggered: {
            const words = root.asked.split(/\s+/).filter(Boolean);
            if (words.length === 0)
                return;
            rg.running = false;
            const longest = words.reduce((a, b) => (b.length > a.length ? b : a));
            const roots = root.shared.roots.slice();
            if (root.shared.docsOn)
                roots.push(root.shared.docsDir);
            rg.seq = root.askedSeq;
            rg.text = root.asked;
            rg.command = ["sh", "-c", 'w=$1; shift; rg -i -F --no-heading -n --max-columns 300 --max-columns-preview --max-count 4 --max-filesize 1M -g "!*.min.*" -g "!*.map" -g "!*.lock" -g "!package-lock.json" -g "!*.svg" -e "$w" "$@" 2>/dev/null | head -n 800', "sh", longest, ...roots];
            rg.running = true;
        }
    }

    readonly property Process ripgrep: Process {
        id: rg

        property int seq: -1
        property string text: ""

        stdout: StdioCollector {
            onStreamFinished: root.publishFrom(rg.seq, rg.text, text)
        }
    }

    function snippet(line: string): string {
        line = line.trim().replace(/\s+/g, " ");
        return line.length > 150 ? line.slice(0, 150) + "…" : line;
    }

    function publishFrom(seq: int, text: string, out: string): void {
        const f = shared;
        const best = new Map();
        const words = text.toLowerCase().split(/\s+/).filter(Boolean);
        for (const raw of out.split("\n")) {
            const m = /^(.*?):(\d+):(.*)$/.exec(raw);
            if (!m)
                continue;
            // Every word on the line, in any order; the fuzzy score only
            // ranks (a tight run over words far apart).
            const lower = m[3].toLowerCase();
            if (!words.every(w => lower.includes(w)))
                continue;
            const s = Math.max(Fuzzy.score(m[3], text), 20);
            const cur = best.get(m[1]);
            if (!cur || s > cur.s)
                best.set(m[1], { s: s, n: parseInt(m[2]), line: m[3] });
        }
        const results = [];
        for (const [file, b] of best) {
            const inDoc = file.startsWith(f.docsDir + "/");
            const origin = inDoc ? f.docPaths[file.slice(f.docsDir.length + 1).replace(/\.txt$/, "")] : file;
            if (!origin)
                continue;
            const name = origin.slice(origin.lastIndexOf("/") + 1);
            const dir = origin.slice(0, origin.lastIndexOf("/")).replace(Quickshell.env("HOME"), "~");
            results.push({
                title: snippet(b.line),
                subtitle: `${name}${inDoc ? "" : " : " + b.n}   ·   ${dir}`,
                icon: inDoc ? "picture_as_pdf" : "manage_search",
                score: b.s,
                // A text file: around the matching line; a document: its text.
                preview: { kind: "file", path: origin, line: inDoc ? 0 : b.n },
                key: "",
                run: () => Open.open(origin),
                actions: [
                    ...(inDoc ? [] : [{
                                label: `Open at line ${b.n} in VS Code`,
                                icon: "code",
                                run: () => Quickshell.execDetached(["code", "-g", `${origin}:${b.n}`])
                            }]),
                    {
                        label: "Show in the file manager",
                        icon: "folder_open",
                        run: () => Quickshell.execDetached(["dolphin", "--select", origin])
                    },
                    {
                        label: "Copy the path",
                        icon: "content_copy",
                        run: () => Clipboard.copyText(origin)
                    }
                ]
            });
        }
        results.sort((a, b) => b.score - a.score);
        publish(seq, results.slice(0, 30));
    }
}
