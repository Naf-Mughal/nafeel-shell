pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Open a URL or a file with its default app, and take the desktop there: the
// app's window (the most recently used one) and its workspace first, then the
// open, so the page or the file lands in front of you. A plain xdg-open hands
// it to the running app and the compositor leaves you where you were (a new
// tab in a browser on another workspace). With no window of that app, it just
// opens (a new window comes up focused).
Singleton {
    id: root

    property var queue: []

    function open(target: string): void {
        queue = queue.concat([target]);
        if (!resolver.running)
            next();
    }

    function next(): void {
        if (queue.length === 0)
            return;
        const target = queue[0];
        queue = queue.slice(1);
        resolver.target = target;
        resolver.command = ["sh", "-c", 'case "$1" in http://*|https://*|ftp://*|mailto:*) m="x-scheme-handler/${1%%:*}" ;; *) m=$(xdg-mime query filetype "$1" 2>/dev/null) ;; esac; xdg-mime query default "$m" 2>/dev/null', "sh", target];
        resolver.running = true;
    }

    // Whose window shows it: the desktop entry of the default handler.
    function handler(desktopId: string): var {
        const id = desktopId.trim().replace(/\.desktop$/, "");
        return id ? (DesktopEntries.byId(id) ?? DesktopEntries.byId(id + ".desktop")) : null;
    }

    function go(target: string, desktopId: string): void {
        const app = handler(desktopId);
        const order = Umbriel.mru;
        const windows = !app ? [] : Umbriel.windows.filter(w => Apps.forAppId(w.app_id)?.id === app.id).sort((a, b) => (order.indexOf(a.id) + 1 || 1e9) - (order.indexOf(b.id) + 1 || 1e9));
        const steps = [];
        if (windows.length > 0) {
            const w = windows[0];
            const ws = Umbriel.workspaces.find(x => x.id === w.workspace);
            if (ws && !ws.active)
                steps.push(`workspace-switch:${ws.name}/${ws.output}`);
            steps.push(`window-focus:${w.id}`);
        }
        // Focus first (the browser opens the tab in the window that has it),
        // then the open, in one shell so they arrive in order.
        Quickshell.execDetached(["sh", "-c", 't=$1; shift; for a in "$@"; do umbriel msg "$a"; done; exec xdg-open "$t"', "sh", target, ...steps]);
    }

    Process {
        id: resolver

        property string target: ""

        stdout: StdioCollector {
            onStreamFinished: {
                root.go(resolver.target, text);
                root.next();
            }
        }
    }
}
