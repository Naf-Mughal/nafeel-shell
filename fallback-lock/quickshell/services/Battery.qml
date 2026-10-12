pragma Singleton
import QtQuick
import Quickshell.Io

// Battery level for the lock HUD, read straight from sysfs.
Item {
    id: root

    property real percentage: 0
    property bool charging: false

    FileView {
        id: capacityFile
        path: "/sys/class/power_supply/BAT0/capacity"
        printErrors: false
        onLoaded: root.percentage = parseInt(text()) || 0
    }

    FileView {
        id: statusFile
        path: "/sys/class/power_supply/BAT0/status"
        printErrors: false
        onLoaded: root.charging = text().trim() === "Charging"
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            capacityFile.reload();
            statusFile.reload();
        }
    }
}
