pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The installed font families, for the font picker: every family Qt knows
// (the system's and the ones the shell loads), and, apart, the fixed-width
// ones (fontconfig's spacing=mono, the Nerd Font Mono families too).
// Read once, when first asked for.
Singleton {
    id: root

    property bool wanted: false
    readonly property var all: wanted ? Qt.fontFamilies().filter(f => f && !f.startsWith(".")) : []
    property var mono: []

    function want(): void {
        if (wanted)
            return;
        wanted = true;
        lister.running = true;
    }

    Process {
        id: lister

        command: ["sh", "-c", "fc-list :spacing=mono family | sed 's/,.*//' | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: root.mono = text.split("\n").map(l => l.trim()).filter(Boolean)
        }
    }
}
