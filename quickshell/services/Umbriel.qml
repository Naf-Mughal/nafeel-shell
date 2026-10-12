pragma Singleton

// umbriel compositor state, live from its IPC event socket
// ($UMBRIEL_SOCKET, or $XDG_RUNTIME_DIR/umbriel-$WAYLAND_DISPLAY.sock).
// Every event carries the full list, so each one simply replaces the model.
//
//   workspaces  [{ id: "eDP-1:1", index, name, output, active, focused, occupied, layout }]
//   windows     [{ id, app_id, title, workspace, focused, active, floating, x, y, w, h, pid, … }]
//   mru         window ids, most recently focused first (the switcher's order)
//   submap      the active keybind submap ("" for none)
//
// It also writes the shell's own umbriel fragment,
// ~/.config/umbriel/plugins/shell-frost.toml: the frosted-paper blur behind
// the shell's surfaces, while the paper setting isn't solid.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    // ── Frosted paper ──
    // umbriel blurs what's behind the shell's surfaces, only inside their
    // shapes (ignore_alpha), windows under an open panel included (not
    // optimized). Written once the settings are read, and when paper changes.
    readonly property bool frosted: Tokens.transparency.enabled
    readonly property string frostText: "# Written by the shell (services/Umbriel.qml); edits here are overwritten.\n" + "# Included from ~/.config/umbriel/config.toml.\n" + (frosted ? "\n# Frosted paper: blur behind the shell's frame and panels.\n[[layer_rule]]\nmatch.namespace = \"^nafeel-shell\"\nblur = true\nblur_ignore_alpha = 0.05\nblur_optimized = false\n" : "\n# Paper is solid: no blur.\n")

    function writeFrost(): void {
        if (Settings.loaded && frostFile.loadedText !== frostText) {
            frostFile.setText(frostText);
            frostFile.loadedText = frostText;
        }
    }

    onFrostTextChanged: writeFrost()

    Connections {
        target: Settings

        function onLoadedChanged(): void {
            root.writeFrost();
        }
    }

    FileView {
        id: frostFile

        property string loadedText: ""

        path: Quickshell.env("HOME") + "/.config/umbriel/plugins/shell-frost.toml"
        printErrors: false
        onLoaded: {
            loadedText = text();
            root.writeFrost();
        }
        onLoadFailed: root.writeFrost()
    }

    readonly property string socketPath: Quickshell.env("UMBRIEL_SOCKET") || `${Quickshell.env("XDG_RUNTIME_DIR")}/umbriel-${Quickshell.env("WAYLAND_DISPLAY")}.sock`

    property var workspaces: []
    property var windows: []
    property bool overviewOpen: false
    property var layouts: []
    property int layoutIndex: 0
    readonly property string layout: layouts[layoutIndex] ?? ""
    // Something is capturing the screen (screen sharing / recording).
    property bool screencast: false
    property var mru: []
    property string submap: ""
    readonly property bool connected: events.connected

    readonly property var focusedWindow: windows.find(w => w.focused) ?? null
    readonly property string focusedOutput: workspaces.find(w => w.focused)?.output ?? ""

    function workspacesOn(output: string): var {
        return workspaces.filter(w => w.output === output).sort((a, b) => a.index - b.index);
    }

    function activeWorkspace(output: string): var {
        return workspaces.find(w => w.output === output && w.active) ?? null;
    }

    function windowsOn(workspaceId: string): var {
        return windows.filter(w => w.workspace === workspaceId);
    }

    // Whether a window fills the output on its active workspace. umbriel has no
    // foreign-toplevel protocol, so fullscreen is read from the window size (a
    // fullscreen window keeps its tile x/y but takes the output's size).
    // No windows on the output's active workspace (the wallpaper is all there
    // is to see).
    function emptyOn(output: string): bool {
        const ws = activeWorkspace(output);
        return !!ws && !windows.some(w => w.workspace === ws.id);
    }

    function fullscreenOn(output: string, width: int, height: int): bool {
        const ws = activeWorkspace(output);
        return !!ws && windows.some(w => w.workspace === ws.id && w.w >= width && w.h >= height);
    }

    // Show the desktop (Mod+D): from a workspace with windows, go to an empty
    // one on the same screen; from there, back to where you were.
    property var desktopFrom: ({})

    function toggleDesktop(output: string): void {
        output = output || focusedOutput;
        const ws = activeWorkspace(output);
        if (!ws)
            return;
        const from = desktopFrom[output];
        if (!ws.occupied) {
            if (from) {
                const d = Object.assign({}, desktopFrom);
                delete d[output];
                desktopFrom = d;
                dispatch(`workspace-switch:${from}/${output}`);
            }
            return;
        }
        // The first empty one (umbriel keeps one at the end of the list).
        const empty = workspacesOn(output).find(w => !w.occupied);
        if (!empty)
            return;
        const d = Object.assign({}, desktopFrom);
        d[output] = ws.name;
        desktopFrom = d;
        dispatch(`workspace-switch:${empty.name}/${output}`);
    }

    IpcHandler {
        target: "desktop"

        function toggle(): void {
            root.toggleDesktop("");
        }
    }

    // Run a compositor action, as `umbriel msg <action>`.
    function dispatch(action: string): void {
        Quickshell.execDetached(["umbriel", "msg", action]);
    }

    // Most recently focused first: the focused window to the front, closed
    // ones out, new ones (never focused yet) at the back in layout order.
    function updateMru(): void {
        const ids = windows.map(w => w.id);
        const next = mru.filter(id => ids.includes(id));
        for (const id of ids)
            if (!next.includes(id))
                next.push(id);
        const focused = windows.find(w => w.focused)?.id;
        if (focused && next[0] !== focused) {
            next.splice(next.indexOf(focused), 1);
            next.unshift(focused);
        }
        mru = next;
    }

    function handle(line: string): void {
        let msg;
        try {
            msg = JSON.parse(line);
        } catch (e) {
            return;
        }
        switch (msg.event) {
        case "workspaces":
            workspaces = msg.data ?? [];
            break;
        case "windows":
            windows = msg.data ?? [];
            updateMru();
            break;
        case "submap":
            submap = msg.data?.name ?? msg.data?.submap ?? (typeof msg.data === "string" ? msg.data : "");
            break;
        case "overview":
            overviewOpen = msg.data?.open ?? false;
            break;
        case "keyboard_layout":
            layouts = msg.data?.names ?? [];
            layoutIndex = msg.data?.current_index ?? 0;
            break;
        case "screencast":
            screencast = (msg.data?.kind ?? "clear") !== "clear";
            break;
        }
    }

    Socket {
        id: events

        path: root.socketPath

        onConnectedChanged: {
            if (connected) {
                write('{"cmd":"subscribe","events":["workspaces","windows","overview","keyboard_layout","screencast","submap"]}\n');
                flush();
            } else {
                reconnect.restart();
            }
        }

        parser: SplitParser {
            onRead: line => root.handle(line)
        }
    }

    // Connect only once the parser is attached; an early connect crashes.
    Component.onCompleted: events.connected = true

    Timer {
        id: reconnect

        interval: 1000
        onTriggered: events.connected = true
    }
}
