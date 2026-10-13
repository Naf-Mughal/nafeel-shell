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

    // A place in the queue.
    function enlist(): int {
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

        interval: 150
        repeat: true
        onTriggered: {
            if (root.step < root.enlisted)
                root.step++;
            else
                stop();
        }
    }

    // Late askers (a plugin switched on later) get their turn at once.
    onEnlistedChanged: {
        if (started && !tick.running)
            tick.start();
    }
}
