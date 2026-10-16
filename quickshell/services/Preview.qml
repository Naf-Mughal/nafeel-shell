pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// What the launcher's preview shows for the selected result: its `preview`
// (an object, or a function making one, evaluated only for the selected
// result): { kind: "file", path, line?, title }, { kind: "text", text },
// { kind: "image", path }, { kind: "glyph", glyph, title, lines },
// { kind: "app", … }, { kind: "window", id, … }, { kind: "info", title, lines }.
// A file's content is read by plugins/files/preview.py (one process per
// selection, after a pause: arrowing down a list doesn't run one per row).
Singleton {
    id: root

    readonly property var spec: {
        const r = Launcher.current;
        if (!r)
            return null;
        const p = typeof r.preview === "function" ? r.preview() : r.preview;
        return p ?? { kind: "info", title: r.title, lines: r.subtitle ? [r.subtitle] : [] };
    }

    // preview.py's answer for the current file spec, and whose it is.
    property var data: null
    property string loadedFor: ""
    readonly property string wanted: spec?.kind === "file" ? `${spec.path}:${spec.line ?? 0}` : ""
    readonly property bool loading: wanted !== "" && loadedFor !== wanted

    onWantedChanged: {
        if (wanted === "") {
            data = null;
            loadedFor = "";
            return;
        }
        pause.restart();
    }

    Timer {
        id: pause

        interval: 90
        onTriggered: {
            if (root.wanted === "" || root.wanted === proc.key)
                return;
            proc.running = false;
            proc.key = root.wanted;
            proc.command = ["python3", Quickshell.shellDir + "/plugins/files/preview.py", root.spec.path, String(root.spec.line ?? 0)];
            proc.running = true;
        }
    }

    Process {
        id: proc

        property string key: ""

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.data = JSON.parse(text);
                } catch (e) {
                    root.data = { kind: "none", text: "", meta: [] };
                }
                root.loadedFor = proc.key;
            }
        }
    }
}
