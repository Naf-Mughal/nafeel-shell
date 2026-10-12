pragma Singleton

// The `=` calculator, through qalc (libqalculate: units, currency, …).

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string result: ""
    property string pending: ""

    function evaluate(expr: string): void {
        expr = expr.trim();
        if (!expr) {
            result = "";
            return;
        }
        pending = expr;
        debounce.restart();
    }

    Timer {
        id: debounce

        interval: 120
        onTriggered: {
            proc.command = ["qalc", "-t", root.pending];
            proc.running = true;
        }
    }

    Process {
        id: proc

        stdout: StdioCollector {
            onStreamFinished: root.result = text.trim()
        }
    }
}
