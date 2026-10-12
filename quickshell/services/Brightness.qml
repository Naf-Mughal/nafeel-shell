pragma Singleton

// The laptop panel's backlight, read from sysfs whenever udev reports a
// change, set with brightnessctl.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string device: ""
    property int max: 0
    property int raw: 0
    readonly property bool available: device !== "" && max > 0
    readonly property real level: available ? raw / max : 0

    // (Kept for callers; the level is always live now.)
    property int watchers: 0

    function set(v: real): void {
        const c = Math.max(0.01, Math.min(1, v));
        Quickshell.execDetached(["brightnessctl", "-q", "-d", device, "set", `${Math.round(c * 100)}%`]);
        raw = Math.round(c * max);
    }

    // Set by the shell itself (idle dimming): the OSD stays out of it.
    property bool quiet: false

    function quietly(v: real): void {
        quiet = true;
        set(v);
        unquiet.restart();
    }

    Timer {
        id: unquiet

        interval: 1500
        onTriggered: root.quiet = false
    }

    function step(up: bool): void {
        Quickshell.execDetached(["brightnessctl", "-q", "-d", device, "set", up ? "5%+" : "5%-"]);
    }

    Process {
        running: true
        command: ["sh", "-c", 'for d in /sys/class/backlight/*; do [ -r "$d/max_brightness" ] && { echo "${d##*/} $(cat "$d/max_brightness")"; exit; }; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const [dev, max] = text.trim().split(" ");
                root.device = dev ?? "";
                root.max = parseInt(max) || 0;
            }
        }
    }

    FileView {
        id: file

        path: root.device ? `/sys/class/backlight/${root.device}/brightness` : ""
        onLoaded: root.raw = parseInt(text()) || 0
    }

    // Every backlight change, from any source (keys, Noctalia, brightnessctl).
    Process {
        running: root.available
        // Dies with the shell (pdeathsig): a restart leaves no monitor behind.
        command: ["setpriv", "--pdeathsig", "TERM", "udevadm", "monitor", "--udev", "--subsystem-match=backlight"]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes("change"))
                    file.reload();
            }
        }
    }

    Component.onCompleted: Qt.callLater(() => file.reload())
}
