pragma Singleton

// Alt+Tab: the windows on every screen's active workspace, most recently
// focused first. Alt+Tab opens it on the window before this one (so a quick
// tap flips between the last two), Tab / Shift+Tab move while Alt is held,
// and letting go of Alt focuses the selection. Esc or a click outside
// cancels.
//
// While it's open the shell enters umbriel's "switcher" submap, where Alt+Tab
// isn't a compositor bind, so Tab reaches the switcher straight away instead
// of through a keybind process per press.
//
//   qs -p <shell> ipc call switcher next      (Alt+Tab)
//   qs -p <shell> ipc call switcher prev      (Alt+Shift+Tab)
//   qs -p <shell> ipc call switcher peek      (show it without the keyboard)
//   qs -p <shell> ipc call switcher cancel

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

Singleton {
    id: root

    // The windows, as they were when it opened.
    property var list: []
    property int index: 0
    // Opened by a held shortcut: letting go of the modifier commits.
    property bool holding: false
    readonly property bool open: ShellState.pinned === "switcher" || ShellState.previewed === "switcher"
    readonly property var selected: list[index] ?? null
    property bool inSubmap: false
    // Whether the carousel shows. A held Alt+Tab waits a beat first, so a
    // quick tap switches without the panel ever appearing.
    property bool shown: false
    readonly property int revealDelay: ShellState.settings.v["switcher.revealDelay"]

    function candidates(): var {
        const active = Umbriel.workspaces.filter(w => w.active).map(w => w.id);
        const byId = {};
        for (const w of Umbriel.windows)
            byId[w.id] = w;
        return Umbriel.mru.map(id => byId[id]).filter(w => w && active.includes(w.workspace));
    }

    function start(step: int, hold: bool, peek: bool): void {
        if (open && list.length > 0) {
            move(step);
            return;
        }
        const windows = candidates();
        if (windows.length === 0)
            return;
        list = windows;
        index = windows.length === 1 ? 0 : step > 0 ? 1 : windows.length - 1;
        holding = hold && !peek;
        shown = !holding;
        if (!shown)
            reveal.restart();
        if (peek) {
            ShellState.preview("switcher", Umbriel.focusedOutput);
        } else {
            ShellState.pin("switcher", Umbriel.focusedOutput);
            inSubmap = true;
            Umbriel.dispatch("submap:switcher");
        }
    }

    function move(step: int): void {
        // Stepping through means looking: show it now.
        shown = true;
        if (list.length > 0)
            index = (index + step + list.length) % list.length;
    }

    function select(i: int): void {
        if (i >= 0 && i < list.length)
            index = i;
    }

    function commit(): void {
        const w = selected;
        finish();
        if (w)
            Umbriel.dispatch("window-focus:" + w.id);
    }

    function cancel(): void {
        finish();
    }

    function finish(): void {
        holding = false;
        if (open)
            ShellState.close();
    }

    onOpenChanged: {
        if (open)
            return;
        holding = false;
        shown = false;
        reveal.stop();
        if (inSubmap) {
            inSubmap = false;
            Umbriel.dispatch("submap:reset");
        }
    }

    Timer {
        id: reveal

        interval: root.revealDelay
        onTriggered: root.shown = true
    }

    // A shell that went down mid-switch left umbriel in the submap: leave it.
    Connections {
        target: Umbriel

        function onSubmapChanged(): void {
            if (Umbriel.submap === "switcher" && !root.open)
                Umbriel.dispatch("submap:reset");
        }
    }

    IpcHandler {
        target: "switcher"

        function next(): void {
            root.start(1, true, false);
        }

        function prev(): void {
            root.start(-1, true, false);
        }

        function peek(): void {
            root.start(1, false, true);
        }

        function cancel(): void {
            root.cancel();
        }

        // What it shows: "index/count id,id,…" (for testing).
        function state(): string {
            return `${root.index}/${root.list.length} ${root.list.map(w => w.title).join(" | ")}`;
        }
    }
}
