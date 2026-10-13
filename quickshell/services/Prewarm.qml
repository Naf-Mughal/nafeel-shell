pragma Singleton

import QtQuick
import Quickshell

// Builds every panel ahead of time (the user's ask: never a first-open
// stutter, after a restart too): a panel's content asks for a turn
// (`enlist`), and a few seconds after the shell starts the turns come one by
// one, ~150 ms apart, so the building is spread out and the shell stays
// smooth while it happens. A Loader is made once its turn has come (`due`),
// asynchronously, and stays made (warm).
Singleton {
    id: root

    // How many have asked, and how many turns have come.
    property int enlisted: 0
    property int step: 0
    readonly property bool done: step >= enlisted && started

    property bool started: false

    // Who's in the queue, by place (for the log).
    property var names: []
    // NAFEEL_PREWARM_LOG=1: a turn every 1.5 s, each logged ("prewarm:
    // <name>"), to measure what each panel costs (bin/mem-prewarm).
    readonly property bool logging: Quickshell.env("NAFEEL_PREWARM_LOG") === "1"

    // A place in the queue.
    function enlist(name: string): int {
        names.push(name ?? "");
        return enlisted++;
    }

    // Whether the turn of the one holding place `n` has come.
    function due(n: int): bool {
        return n >= 0 && n < step;
    }

    Timer {
        // After the first frames and the services' start.
        running: true
        interval: 2500
        onTriggered: {
            root.started = true;
            tick.start();
        }
    }

    Timer {
        id: tick

        interval: root.logging ? 1500 : 150
        repeat: true
        onTriggered: {
            if (root.step < root.enlisted) {
                if (root.logging)
                    console.info(`prewarm: ${root.names[root.step] || root.step}`);
                root.step++;
            } else {
                if (root.logging)
                    console.info("prewarm: done");
                stop();
            }
        }
    }

    // Late askers (a plugin switched on later) get their turn at once.
    onEnlistedChanged: {
        if (started && !tick.running)
            tick.start();
    }
}
