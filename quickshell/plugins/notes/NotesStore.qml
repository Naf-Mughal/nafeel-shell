// Notes: plain Markdown files in a folder you own (~/Documents/Notes, as
// Noctalia's notes keep them: yours to sync, grep and edit anywhere), with a
// Scratchpad always at the top for dumping text without naming anything.
// Pins and the last open note live in ~/.local/state/nafeel-shell/notes.json.
//
//   notes      [{ name, path, mtime, pinned, scratch, preview }], pinned first,
//              then the most recently changed
//   create() / rename(old, new) / remove(name) (to the trash) / togglePin(name)
//   jot(text)  append a line to the Scratchpad (launcher, IPC)
//
// Bus: "notes.changed" after any change of the folder.
// IPC: qs -p <shell> ipc call notes jot <text> | create <text>

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// One per enabled notes plugin (its root makes it; Plugins.instance("notes")
// .store hands it to the drawer), gone when the plugin is switched off.
Scope {
    id: root

    // The Settings panel's Notes page.
    readonly property SettingsPage settings: SettingsPage {
        name: "notes"
        title: "Notes"
        gloss: "笔记"
        icon: "edit_note"
        order: 70
        description: "Where notes are kept."

        SettingItem {
            key: "notes.dir"
            kind: "text"
            icon: "folder"
            label: "Folder"
            description: "Notes are plain Markdown files here, easy to sync or edit elsewhere."
            placeholder: "~/Documents/Notes"
            def: "~/Documents/Notes"
        }
    }
    readonly property string dir: {
        const d = (settings.v["notes.dir"] ?? "").trim() || "~/Documents/Notes";
        return (d.startsWith("~") ? Quickshell.env("HOME") + d.slice(1) : d).replace(/\/+$/, "");
    }
    readonly property string ext: "md"
    readonly property string scratchName: "Scratchpad"
    readonly property string statePath: Quickshell.env("HOME") + "/.local/state/nafeel-shell/notes.json"
    // The single-note pad this replaces: carried into the Scratchpad once.
    readonly property string oldPad: Quickshell.env("HOME") + "/.local/state/nafeel-shell/notes.md"

    property var notes: []
    property var pinned: []
    property string last: scratchName
    property bool ready: false

    function pathOf(name: string): string {
        return `${dir}/${name}.${ext}`;
    }

    onDirChanged: rescan()

    function rescan(): void {
        lister.running = true;
    }

    // A new note, named after now ("Note 12 Oct 11.20"), made unique.
    function create(text: string): string {
        const d = new Date();
        const base = "Note " + Qt.formatDateTime(d, "d MMM hh.mm");
        let name = base, n = 2;
        while (notes.some(x => x.name === name))
            name = `${base} (${n++})`;
        _run(["sh", "-c", 'mkdir -p "$1" && printf "%s" "$3" > "$2"', "sh", dir, pathOf(name), text ?? ""]);
        last = name;
        _saveState();
        return name;
    }

    function rename(from: string, to: string): bool {
        to = (to ?? "").replace(/[\/\\:*?"<>|]/g, " ").trim();
        if (!to || to === from || from === scratchName || notes.some(x => x.name === to))
            return false;
        _run(["mv", "-n", pathOf(from), pathOf(to)]);
        pinned = pinned.map(p => p === from ? to : p);
        if (last === from)
            last = to;
        _saveState();
        return true;
    }

    // To the trash (gio), not gone.
    function remove(name: string): void {
        if (name === scratchName)
            return;
        _run(["sh", "-c", 'gio trash "$1" 2>/dev/null || rm -f "$1"', "sh", pathOf(name)]);
        pinned = pinned.filter(p => p !== name);
        if (last === name)
            last = scratchName;
        _saveState();
    }

    function togglePin(name: string): void {
        if (name === scratchName)
            return;
        pinned = pinned.includes(name) ? pinned.filter(p => p !== name) : [...pinned, name];
        _saveState();
        _sort(notes);
    }

    function jot(text: string): void {
        if (!text)
            return;
        _run(["sh", "-c", 'mkdir -p "$1" && f="$2" && { [ -s "$f" ] && [ "$(tail -c1 "$f")" != "" ] && echo >> "$f"; printf "%s\\n" "$3" >> "$f"; }', "sh", dir, pathOf(scratchName), text]);
    }

    function open(name: string): void {
        last = name;
        _saveState();
    }

    // A write from the editor (the folder listing follows).
    function saved(): void {
        rescan();
    }

    function _run(cmd: var): void {
        const p = runner.createObject(root, {
            command: cmd
        });
        p.running = true;
    }

    function _sort(list: var): void {
        notes = list.map(n => Object.assign({}, n, {
                pinned: n.scratch || pinned.includes(n.name)
            })).sort((a, b) => (b.scratch - a.scratch) || (b.pinned - a.pinned) || (b.mtime - a.mtime));
    }

    function _saveState(): void {
        stateFile.setText(JSON.stringify({
            pinned,
            last
        }, null, 2) + "\n");
    }

    Component {
        id: runner

        Process {
            onExited: {
                root.rescan();
                destroy();
            }
        }
    }

    // name \t mtime \t first line, for every note.
    Process {
        id: lister

        command: ["sh", "-c", 'mkdir -p "$1"; [ -e "$1/$2.md" ] || { [ -s "$3" ] && cp "$3" "$1/$2.md" || : > "$1/$2.md"; }; for f in "$1"/*.md; do [ -f "$f" ] || continue; n=$(basename "$f" .md); m=$(stat -c %Y "$f"); l=$(grep -m1 -v "^\\s*$" "$f" | cut -c1-120); printf "%s\\t%s\\t%s\\n" "$n" "$m" "$l"; done', "sh", root.dir, root.scratchName, root.oldPad]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = text.split("\n").filter(l => l).map(l => {
                    const [name, mtime, preview] = l.split("\t");
                    return {
                        name,
                        path: root.pathOf(name),
                        mtime: parseInt(mtime) || 0,
                        scratch: name === root.scratchName,
                        preview: (preview ?? "").replace(/^#+\s*/, "")
                    };
                });
                root._sort(list);
                root.ready = true;
                Bus.publish("notes.changed", {
                    count: list.length
                });
            }
        }
    }

    FileView {
        id: stateFile

        path: root.statePath
        printErrors: false
        onLoaded: {
            try {
                const s = JSON.parse(text());
                root.pinned = s.pinned ?? [];
                root.last = s.last ?? root.scratchName;
            } catch (e) {}
            root.rescan();
        }
        onLoadFailed: root.rescan()
    }

    IpcHandler {
        target: "notes"

        function jot(text: string): void {
            root.jot(text);
        }
        function create(text: string): void {
            root.create(text);
            ShellState.pin("notes", Umbriel.focusedOutput);
        }
    }
}
