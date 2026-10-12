pragma Singleton

// The shell-wide ink transition. Every window with an InkStill (the
// wallpaper, the frame and its panels) takes a still of itself; the change
// happens underneath (new colours, new wallpaper) while the stills hide it;
// then the stills give way together from the same point, behind one wet ink
// front. The new look is in place the moment the ink has soaked through.
//
//   Ink.ink(() => { …change things… }, Qt.point(0.5, 0.5))
//
// Bus: "ink.started", "ink.finished".

import QtQuick
import Quickshell
import qs.config

Singleton {
    id: root

    // Shown by the InkStills while a transition runs.
    property bool frozen: false
    // The stills are being taken (InkStills are in the scene, still clear).
    property bool capturing: false
    // 0 = the old look, 1 = the new.
    property real progress: 1
    property point origin: Qt.point(0.5, 0.5)
    readonly property bool running: frozen

    property var _change: null
    property var _queued: null

    // InkStills take their stills on this.
    signal capture

    function ink(change: var, origin: point): void {
        if (frozen) {
            // One at a time: the latest change waits for this one.
            _queued = {
                change,
                origin
            };
            return;
        }
        if (Tokens.reduceMotion) {
            change();
            return;
        }
        root.origin = origin ?? Qt.point(0.5, 0.5);
        _change = change;
        progress = 1;
        capturing = true;
        capture();
        // A couple of frames for the stills to render, then they cover.
        settle.restart();
    }

    Timer {
        id: settle

        interval: 48
        onTriggered: {
            root.progress = 0;
            root.frozen = true;
            root.capturing = false;
            Bus.publish("ink.started", {});
            // Underneath the stills now: change it all.
            Qt.callLater(() => {
                const change = root._change;
                if (change)
                    change();
                root._change = null;
                // The new look needs a frame to draw before it shows through.
                start.restart();
            });
        }
    }

    Timer {
        id: start

        interval: 32
        onTriggered: soak.restart()
    }

    NumberAnimation {
        id: soak

        target: root
        property: "progress"
        from: 0
        to: 1
        duration: Tokens.dur(1500)
        easing.type: Easing.InOutSine
        onFinished: {
            root.frozen = false;
            Bus.publish("ink.finished", {});
            const q = root._queued;
            root._queued = null;
            if (q)
                root.ink(q.change, q.origin);
        }
    }
}
