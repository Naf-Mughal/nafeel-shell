import QtQuick
import Quickshell
import Nafeel
import qs.components
import qs.services

// Files and folders by name and by path (the words of a path count: "code
// launcher" finds .../code/launcher.md). The list is the files plugin's
// (fd); scored natively, so ~10k entries cost a few ms a keystroke.
LauncherProvider {
    id: root

    name: "Files"
    icon: "folder_open"
    keyword: "f"
    weight: 0.9
    limit: 15

    readonly property var shared: Plugins.instance("files")

    property string waitingText: ""
    property int waitingSeq: -1

    readonly property var icons: ({
            pdf: "picture_as_pdf", doc: "description", docx: "description", odt: "description", txt: "article", md: "article", rtf: "article", epub: "menu_book",
            xls: "table_chart", xlsx: "table_chart", ods: "table_chart", csv: "table_chart", ppt: "slideshow", pptx: "slideshow", odp: "slideshow",
            png: "image", jpg: "image", jpeg: "image", gif: "image", webp: "image", svg: "image", avif: "image", bmp: "image",
            mp4: "movie", mkv: "movie", webm: "movie", mov: "movie", avi: "movie", mp3: "music_note", flac: "music_note", ogg: "music_note", wav: "music_note", m4a: "music_note", opus: "music_note",
            zip: "folder_zip", tar: "folder_zip", gz: "folder_zip", xz: "folder_zip", zst: "folder_zip", "7z": "folder_zip", rar: "folder_zip",
            js: "code", ts: "code", tsx: "code", jsx: "code", py: "code", rs: "code", go: "code", c: "code", cpp: "code", h: "code", qml: "code", java: "code", sh: "terminal", json: "data_object", toml: "settings", yaml: "settings", yml: "settings", html: "html", css: "css"
        })

    function iconFor(path: string): string {
        if (path.endsWith("/"))
            return "folder";
        const i = path.lastIndexOf(".");
        return i > path.lastIndexOf("/") ? icons[path.slice(i + 1).toLowerCase()] ?? "draft" : "draft";
    }

    function pretty(dir: string): string {
        const h = Quickshell.env("HOME");
        return dir.startsWith(h + "/") ? "~" + dir.slice(h.length) : dir;
    }

    function build(text: string): var {
        const f = shared;
        const ns = Fuzzy.scores(f.names, text), ps = Fuzzy.scores(f.rels, text);
        const hits = [];
        // Letters scattered across a long name aren't a match: ~12 points a
        // typed letter is a run or word starts, not "dolphin" in
        // "setup-hibernate.sh".
        const floor = text.replace(/\s+/g, "").length * 12;
        for (let i = 0; i < ns.length; i++) {
            const s = Math.max(ns[i] * 1.0, ps[i] * 0.55);
            if (s >= floor)
                hits.push([s, i]);
        }
        hits.sort((a, b) => b[0] - a[0]);
        return hits.slice(0, 40).map(([s, i]) => {
            const full = f.paths[i], dir = full.endsWith("/");
            const path = dir ? full.slice(0, -1) : full;
            const parent = path.slice(0, path.lastIndexOf("/"));
            return {
                title: f.names[i],
                subtitle: pretty(parent),
                icon: iconFor(full),
                // A picture's own thumbnail (decoded small, kept on the GPU).
                image: !dir && /\.(png|jpe?g|webp|gif|bmp|avif)$/i.test(path) ? Wallpapers.still(path, true) : "",
                score: s,
                key: "file:" + path,
                run: () => Quickshell.execDetached(["xdg-open", path]),
                actions: [
                    {
                        label: "Show in the file manager",
                        icon: "folder_open",
                        run: () => Quickshell.execDetached(["dolphin", "--select", path])
                    },
                    {
                        label: "Copy the path",
                        icon: "content_copy",
                        run: () => Clipboard.copyText(path)
                    },
                    {
                        label: "Open in VS Code",
                        icon: "code",
                        run: () => Quickshell.execDetached(["code", path])
                    },
                    {
                        label: "Open a terminal here",
                        icon: "terminal",
                        run: () => Quickshell.execDetached(["foot", "-D", dir ? path : parent])
                    }
                ]
            };
        });
    }

    function query(text: string, seq: int): var {
        const f = shared;
        if (!f || !f.namesOn || text === "")
            return [];
        // Unscoped, one letter matches half the disk.
        if (text.length < 2 && Launcher.scope !== root)
            return [];
        if (f.stale)
            f.refresh();
        if (!f.ready) {
            waitingText = text;
            waitingSeq = seq;
            return null;
        }
        return build(text);
    }

    readonly property Connections listed: Connections {
        target: root.shared

        function onListed(): void {
            if (root.waitingSeq >= 0) {
                const s = root.waitingSeq;
                root.waitingSeq = -1;
                root.publish(s, root.build(root.waitingText));
            }
        }
    }
}
