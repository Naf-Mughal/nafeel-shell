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
    prefixes: Object.keys(kinds)

    readonly property var shared: Plugins.instance("files")

    // "pdf: budget", "img: sunset", "code: launcher", "dir: projects": the
    // prefix limits the search to a kind of file (extensions; "dir" folders).
    readonly property var kinds: ({
            pdf: ["pdf"],
            doc: ["docx", "doc", "odt", "rtf"], docs: ["docx", "doc", "odt", "rtf"], word: ["docx", "doc", "odt"],
            sheet: ["xlsx", "xls", "ods", "csv"], excel: ["xlsx", "xls", "ods"], csv: ["csv"],
            slides: ["pptx", "ppt", "odp"], ppt: ["pptx", "ppt", "odp"],
            ebook: ["epub", "mobi"], epub: ["epub"],
            img: ["png", "jpg", "jpeg", "webp", "gif", "bmp", "avif", "svg", "heic"], image: ["png", "jpg", "jpeg", "webp", "gif", "bmp", "avif", "svg", "heic"], pic: ["png", "jpg", "jpeg", "webp", "gif", "bmp", "avif", "svg"],
            png: ["png"], jpg: ["jpg", "jpeg"], svg: ["svg"], gif: ["gif"],
            video: ["mp4", "mkv", "webm", "mov", "avi", "m4v"], vid: ["mp4", "mkv", "webm", "mov", "avi", "m4v"], mp4: ["mp4"],
            audio: ["mp3", "flac", "ogg", "wav", "m4a", "opus"], music: ["mp3", "flac", "ogg", "wav", "m4a", "opus"], mp3: ["mp3"],
            code: ["ts", "tsx", "js", "jsx", "mjs", "py", "rs", "go", "c", "cpp", "cc", "h", "hpp", "qml", "java", "kt", "sh", "lua", "css", "html", "vue", "svelte"],
            ts: ["ts", "tsx"], js: ["js", "jsx", "mjs"], py: ["py"], rs: ["rs"], go: ["go"], cpp: ["cpp", "cc", "h", "hpp"], qml: ["qml"], sh: ["sh"], html: ["html", "htm"], css: ["css"],
            json: ["json"], toml: ["toml"], yaml: ["yaml", "yml"], conf: ["conf", "ini", "toml", "cfg"],
            md: ["md", "mdx"], txt: ["txt"], note: ["md", "txt"], text: ["md", "txt"],
            zip: ["zip", "tar", "gz", "xz", "zst", "7z", "rar"], archive: ["zip", "tar", "gz", "xz", "zst", "7z", "rar"],
            dir: ["/"], folder: ["/"]
        })
    property string waitingText: ""
    property int waitingSeq: -1

    function build(text: string): var {
        const f = shared;
        // A kind: only those extensions (or folders, "/").
        const kind = kinds[Launcher.filter] ?? null;
        const allowed = i => {
            if (!kind)
                return true;
            const p = f.paths[i];
            if (kind[0] === "/")
                return p.endsWith("/");
            if (p.endsWith("/"))
                return false;
            const dot = p.lastIndexOf(".");
            return dot > p.lastIndexOf("/") && kind.includes(p.slice(dot + 1).toLowerCase());
        };
        if (text === "") {
            // Just the kind ("pdf:"): the most used, then by name.
            const all = [];
            for (let i = 0; i < f.paths.length && all.length < 300; i++)
                if (allowed(i))
                    all.push(i);
            all.sort((a, b) => Launcher.frecency("file:" + f.paths[b].replace(/\/$/, "")) - Launcher.frecency("file:" + f.paths[a].replace(/\/$/, "")));
            return all.slice(0, 40).map(i => entry(i, 10));
        }
        const ns = Fuzzy.scores(f.names, text), ps = Fuzzy.scores(f.rels, text);
        const hits = [];
        // Letters scattered across a long name aren't a match: ~12 points a
        // typed letter is a run or word starts, not "dolphin" in
        // "setup-hibernate.sh".
        const floor = text.replace(/\s+/g, "").length * 12;
        for (let i = 0; i < ns.length; i++) {
            const s = Math.max(ns[i] * 1.0, ps[i] * 0.55);
            if (s >= floor && allowed(i))
                hits.push([s, i]);
        }
        hits.sort((a, b) => b[0] - a[0]);
        return hits.slice(0, 40).map(([s, i]) => entry(i, s));
    }

    function entry(i: int, s: real): var {
        return shared.fileResult(shared.paths[i], shared.names[i], s);
    }

    function query(text: string, seq: int): var {
        const f = shared;
        const filtered = Launcher.filter !== "";
        if (!f || !f.namesOn || (text === "" && !filtered))
            return [];
        // Unscoped, one letter matches half the disk.
        if (text.length < 2 && Launcher.scope !== root && !filtered)
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
