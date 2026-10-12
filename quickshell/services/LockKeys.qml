pragma Singleton

// Caps Lock and Num Lock, from the keyboard's LEDs in sysfs (re-read a few
// times a second; sysfs sends no change events for them).

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string capsPath: ""
    property string numPath: ""
    property bool caps: false
    property bool num: false

    Process {
        running: true
        command: ["sh", "-c", 'for l in /sys/class/leds/*::capslock /sys/class/leds/*::numlock; do [ -r "$l/brightness" ] && echo "$l"; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                root.capsPath = (lines.find(l => l.endsWith("::capslock")) ?? "") + (lines.some(l => l.endsWith("::capslock")) ? "/brightness" : "");
                root.numPath = (lines.find(l => l.endsWith("::numlock")) ?? "") + (lines.some(l => l.endsWith("::numlock")) ? "/brightness" : "");
            }
        }
    }

    FileView {
        id: capsFile

        path: root.capsPath
        printErrors: false
        onLoaded: root.caps = parseInt(text()) > 0
    }

    FileView {
        id: numFile

        path: root.numPath
        printErrors: false
        onLoaded: root.num = parseInt(text()) > 0
    }

    Timer {
        running: root.capsPath !== "" || root.numPath !== ""
        repeat: true
        interval: 350
        onTriggered: {
            if (root.capsPath)
                capsFile.reload();
            if (root.numPath)
                numFile.reload();
        }
    }
}
