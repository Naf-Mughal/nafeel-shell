import QtQuick
import Quickshell
import Quickshell.Io
import Nafeel
import qs.config
import qs.services

// The files plugin's root (Plugins.instance("files")): what its launcher
// providers share. The folders searched, the list of names (fd, a few ms for
// ~10k entries, refreshed when it has aged), the document index (the text of
// PDFs and office files, kept by index-docs.py at idle, only on the charger)
// and the settings page.
Scope {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string docsDir: `${Quickshell.env("XDG_CACHE_HOME") || home + "/.cache"}/nafeel-shell/docs`

    readonly property SettingsPage settings: SettingsPage {
        name: "launcher"
        title: "Launcher"
        gloss: "启"
        icon: "search"
        order: 33
        description: "What the command center's search looks through."

        SettingItem {
            key: "files.roots"
            kind: "text"
            icon: "folder_open"
            section: "Files"
            label: "Folders"
            description: "Searched for files, text and documents, separated by spaces (~ is your home). Hidden folders, .gitignore'd files, node_modules and the like are skipped."
            placeholder: "~ /mnt/D"
            def: "~ /mnt/D"
        }
        SettingItem {
            key: "files.names"
            kind: "toggle"
            icon: "description"
            label: "File names"
            description: "Fuzzy search by name and by path."
            def: true
        }
        SettingItem {
            key: "files.content"
            kind: "toggle"
            icon: "manage_search"
            label: "Text inside files"
            description: "Every word you type, anywhere on a line, in any order (ripgrep; text files up to 1 MB)."
            def: true
        }
        SettingItem {
            key: "files.docs"
            kind: "toggle"
            icon: "picture_as_pdf"
            label: "Inside PDFs and documents"
            description: "PDF, Word, Excel, PowerPoint, OpenDocument and EPUB text, indexed in the background on the charger (a few seconds per hundred documents; the text is kept in ~/.cache). Scanned pages have no text to find."
            def: true
        }
    }

    readonly property bool namesOn: settings.v["files.names"] === true
    readonly property bool contentOn: settings.v["files.content"] === true
    readonly property bool docsOn: settings.v["files.docs"] === true
    readonly property var roots: (settings.v["files.roots"] ?? "~").split(/\s+/).filter(Boolean).map(r => r === "~" ? home : r.startsWith("~/") ? home + r.slice(1) : r)

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

    // A launcher result for a file or folder: its icon or thumbnail, the
    // preview, and the actions every file has. `name` is its title.
    function fileResult(full: string, name: string, score: real): var {
        const dir = full.endsWith("/");
        const path = dir ? full.slice(0, -1) : full;
        const parent = path.slice(0, path.lastIndexOf("/"));
        return {
            title: name,
            subtitle: pretty(parent),
            icon: iconFor(full),
            // A picture's own thumbnail (decoded small, kept on the GPU).
            image: !dir && /\.(png|jpe?g|webp|gif|bmp|avif)$/i.test(path) ? Wallpapers.still(path, true) : "",
            score: score,
            preview: { kind: "file", path: path, title: name },
            key: "file:" + path,
            run: () => Open.open(path),
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
    }

    // ── Recent files: opened lately, then changed lately ──
    property var recent: []
    property real recentAt: 0
    readonly property bool recentStale: Date.now() - recentAt > 45000

    function refreshRecent(): void {
        if (recentProc.running || !Settings.loaded)
            return;
        recentProc.command = ["python3", Quickshell.shellDir + "/plugins/files/recent.py", ...roots];
        recentProc.running = true;
    }
    signal recentListed

    Process {
        id: recentProc

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.recent = JSON.parse(text);
                } catch (e) {}
                root.recentAt = Date.now();
                root.recentListed();
            }
        }
    }

    // ── The list of names ──
    property var paths: []
    property var names: []
    property var rels: []
    property real loadedAt: 0
    readonly property bool ready: loadedAt > 0
    readonly property bool stale: Date.now() - loadedAt > 60000
    signal listed

    function refresh(): void {
        if (listing.running || !Settings.loaded)
            return;
        listing.command = ["fd", "-t", "f", "-t", "d", "--exclude", "node_modules", "--exclude", ".git", "--exclude", "target", "--exclude", "__pycache__", "--exclude", ".cache", "--exclude", ".venv", "--exclude", "site-packages", ".", ...root.roots];
        listing.running = true;
    }

    Process {
        id: listing

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(Boolean);
                const base = root.home + "/";
                root.paths = lines;
                root.names = lines.map(l => {
                    const t = l.endsWith("/") ? l.slice(0, -1) : l;
                    return t.slice(t.lastIndexOf("/") + 1);
                });
                root.rels = lines.map(l => l.startsWith(base) ? l.slice(base.length) : l);
                root.loadedAt = Date.now();
                root.listed();
            }
        }
    }

    // ── The document index ──
    // hash -> original path, from the index's own list.
    property var docPaths: ({})
    property bool indexing: false
    property real indexedAt: 0

    function indexNow(): void {
        if (indexer.running || !docsOn || !Settings.loaded)
            return;
        indexing = true;
        indexer.command = ["nice", "-n", "19", "ionice", "-c", "3", "python3", Quickshell.shellDir + "/plugins/files/index-docs.py", docsDir, ...roots];
        indexer.running = true;
    }

    Process {
        id: indexer

        stdout: StdioCollector {
            onStreamFinished: console.info(text.trim())
        }
        onExited: {
            root.indexing = false;
            root.indexedAt = Date.now();
            indexFile.reload();
        }
    }

    FileView {
        id: indexFile

        path: root.docsDir + "/index.tsv"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const map = {};
            for (const line of text().split("\n")) {
                const f = line.split("\t");
                if (f.length >= 4)
                    map[f[0]] = f.slice(3).join("\t");
            }
            root.docPaths = map;
        }
    }

    // Soon after the shell starts, then whenever the charger is in and the
    // last run has aged: on battery, never.
    Timer {
        running: true
        interval: 90000
        onTriggered: {
            root.refresh();
            root.indexNow();
        }
    }

    Timer {
        running: true
        repeat: true
        interval: 1800000
        onTriggered: {
            if (!Power.unplugged && Date.now() - root.indexedAt > 6 * 3600000)
                root.indexNow();
        }
    }

    onRootsChanged: {
        loadedAt = 0;
        refresh();
    }

    IpcHandler {
        target: "files"

        function reindex(): void {
            root.indexNow();
        }
        function status(): string {
            return JSON.stringify({ entries: root.paths.length, documents: Object.keys(root.docPaths).length, indexing: root.indexing, roots: root.roots });
        }
    }
}
