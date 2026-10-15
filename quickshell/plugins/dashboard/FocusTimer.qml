import QtQuick
import Quickshell
import qs.services

// A focus timer (the dashboard's stack): `minutes` of focus counted down,
// do not disturb on while it runs (and back as it was after), a note when
// it's done. Lives in the plugin's root, so it keeps going with the
// dashboard shut.
QtObject {
    id: root

    property int minutes: 25
    property int remaining: minutes * 60
    property bool running: false
    readonly property real progress: 1 - remaining / Math.max(1, minutes * 60)
    readonly property string clock: `${Math.floor(remaining / 60)}:${String(remaining % 60).padStart(2, "0")}`

    property bool _dndBefore: false

    function quiet(on: bool): void {
        const n = Plugins.instance("notifications");
        if (!n)
            return;
        if (on) {
            _dndBefore = n.dnd;
            n.dnd = true;
        } else {
            n.dnd = _dndBefore;
        }
    }

    function start(): void {
        if (remaining <= 0)
            remaining = minutes * 60;
        running = true;
        quiet(true);
    }

    function pause(): void {
        running = false;
        quiet(false);
    }

    function reset(): void {
        running = false;
        quiet(false);
        remaining = minutes * 60;
    }

    property Timer tick: Timer {
        running: root.running
        repeat: true
        interval: 1000
        onTriggered: {
            root.remaining = Math.max(0, root.remaining - 1);
            if (root.remaining === 0) {
                root.running = false;
                root.quiet(false);
                Quickshell.execDetached(["notify-send", "-a", "Focus", "Focus done", `${root.minutes} minutes. Take a breath.`]);
            }
        }
    }
}
