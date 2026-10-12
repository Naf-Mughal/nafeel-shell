pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Bluetooth
import qs.config
import qs.services
import qs.components

// Bluetooth: adapter switch, paired devices (connect / disconnect / forget,
// battery when reported), and a scan for new ones that pairs, trusts and
// connects in one click.
Panel {
    id: root


    // Stop a scan started here when the popout goes away.
    Component.onDestruction: {
        if (BluetoothState.adapter?.discovering)
            BluetoothState.adapter.discovering = false;
    }

    PanelHeader {
        width: parent.width
        gloss: Xian.gloss.bluetooth
        icon: BluetoothState.icon
        title: "Bluetooth"
        subtitle: !BluetoothState.enabled ? "Off" : BluetoothState.connected.length > 0 ? `${BluetoothState.connected.length} connected` : "On"

        StyledSwitch {
            checked: BluetoothState.enabled
            onToggled: BluetoothState.toggle()
        }
    }

    EmptyState {
        width: parent.width
        visible: !BluetoothState.enabled
        icon: "bluetooth_disabled"
        title: "Bluetooth is off"
        hint: "Turn it on to reach headphones, mice and phones"
        actionText: "Turn on"
        onAction: BluetoothState.toggle()
    }

    EmptyState {
        width: parent.width
        visible: BluetoothState.enabled && BluetoothState.paired.length === 0 && !BluetoothState.adapter?.discovering
        icon: "bluetooth_searching"
        title: "No devices yet"
        hint: "Pair headphones, a mouse or a phone"
        actionText: "Scan for devices"
        onAction: BluetoothState.adapter.discovering = true
    }

    SectionLabel {
        visible: BluetoothState.enabled && BluetoothState.paired.length > 0
        text: "Paired"
    }

    Repeater {
        model: BluetoothState.enabled ? BluetoothState.paired : []

        ListRow {
            id: dev

            required property var modelData

            width: root.width
            icon: BluetoothState.deviceIcon(modelData.icon ?? "")
            iconFill: modelData.connected ? 1 : 0
            highlighted: modelData.connected
            title: modelData.name
            subtitle: {
                const state = modelData.state === BluetoothDeviceState.Connecting ? "Connecting…" : modelData.state === BluetoothDeviceState.Disconnecting ? "Disconnecting…" : modelData.connected ? "Connected" : "Not connected";
                return modelData.batteryAvailable ? `${state} · ${Math.round(modelData.battery * 100)}%` : state;
            }
            onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()

            IconButton {
                icon: "delete"
                size: 32
                onClicked: dev.modelData.forget()
            }
        }
    }

    Item {
        visible: BluetoothState.enabled && (BluetoothState.paired.length > 0 || !!BluetoothState.adapter?.discovering)
        width: parent.width
        height: scan.height

        SectionLabel {
            anchors.verticalCenter: parent.verticalCenter
            text: "Available"
        }

        IconButton {
            id: scan

            anchors.right: parent.right
            icon: BluetoothState.adapter?.discovering ? "stop" : "search"
            filled: !!BluetoothState.adapter?.discovering
            size: 36
            onClicked: BluetoothState.adapter.discovering = !BluetoothState.adapter.discovering
        }
    }

    Repeater {
        model: BluetoothState.enabled && BluetoothState.adapter?.discovering ? BluetoothState.available : []

        ListRow {
            required property var modelData

            width: root.width
            icon: BluetoothState.deviceIcon(modelData.icon ?? "")
            title: modelData.name
            subtitle: modelData.pairing || BluetoothState.pending.some(p => p.device === modelData) ? "Pairing…" : "Click to pair"
            onClicked: BluetoothState.pairAndConnect(modelData)
        }
    }

    StyledText {
        visible: BluetoothState.enabled && !!BluetoothState.adapter?.discovering && BluetoothState.available.length === 0
        text: "Searching…"
        color: Colours.palette.m3onSurfaceVariant
        font.pixelSize: 12
        leftPadding: Tokens.spacing.small
    }
}
