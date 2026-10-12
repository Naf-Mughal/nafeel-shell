pragma Singleton

// Wi-Fi and wired state, live from NetworkManager.

import QtQuick
import Quickshell
import Quickshell.Networking

Singleton {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property var active: wifi?.networks.values.find(n => n.connected) ?? null
    readonly property real signal: active?.signalStrength ?? 0

    readonly property string icon: {
        if (wired)
            return "lan";
        if (!wifiEnabled)
            return "wifi_off";
        if (!active)
            return "signal_wifi_0_bar";
        if (signal >= 0.7)
            return "signal_wifi_4_bar";
        if (signal >= 0.45)
            return "network_wifi_3_bar";
        if (signal >= 0.2)
            return "network_wifi_2_bar";
        return "network_wifi_1_bar";
    }

    Binding {
        when: root.wifi !== null
        target: root.wifi
        property: "scannerEnabled"
        value: root.scanners > 0
    }

    // Networks in range, the connected one first, then saved, then by signal.
    readonly property var networks: (wifi?.networks.values ?? []).filter(n => n.name).slice().sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength))

    // Users set this while they show the network list, to keep scanning.
    property int scanners: 0

    function signalIcon(s: real): string {
        return s >= 0.7 ? "signal_wifi_4_bar" : s >= 0.45 ? "network_wifi_3_bar" : s >= 0.2 ? "network_wifi_2_bar" : "network_wifi_1_bar";
    }

    function isOpen(n: var): bool {
        return n.security === WifiSecurityType.Open || n.security === WifiSecurityType.Owe;
    }

    function toggleWifi(): void {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }
}
