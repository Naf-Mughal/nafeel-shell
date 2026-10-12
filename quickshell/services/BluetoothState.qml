pragma Singleton

// The default Bluetooth adapter and its connected devices.

import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool enabled: !!adapter?.enabled
    readonly property var connected: Bluetooth.devices.values.filter(d => d.connected)

    readonly property string icon: !enabled ? "bluetooth_disabled" : connected.length > 0 ? "bluetooth_connected" : "bluetooth"

    readonly property var paired: Bluetooth.devices.values.filter(d => d.paired || d.bonded).sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    readonly property var available: Bluetooth.devices.values.filter(d => !d.paired && !d.bonded && d.deviceName)

    function deviceIcon(icon: string): string {
        if (icon.includes("headset") || icon.includes("headphone"))
            return "headphones";
        if (icon.includes("mouse"))
            return "mouse";
        if (icon.includes("keyboard"))
            return "keyboard";
        if (icon.includes("phone"))
            return "smartphone";
        if (icon.includes("audio") || icon.includes("speaker"))
            return "speaker";
        if (icon.includes("gaming") || icon.includes("joystick"))
            return "sports_esports";
        if (icon.includes("computer"))
            return "computer";
        return "bluetooth";
    }

    // Pair, trust and connect a new device in one go: pair now, then trust
    // and connect once it reports paired (given up after 30 s).
    property var pending: []

    function pairAndConnect(device: var): void {
        pending = [...pending, {
                device: device,
                since: Date.now()
            }];
        device.pair();
    }

    Timer {
        interval: 500
        repeat: true
        running: root.pending.length > 0
        onTriggered: {
            root.pending = root.pending.filter(p => {
                if (p.device.paired) {
                    p.device.trusted = true;
                    p.device.connect();
                    return false;
                }
                return Date.now() - p.since < 30000;
            });
        }
    }

    function toggle(): void {
        if (adapter)
            adapter.enabled = !adapter.enabled;
    }
}
