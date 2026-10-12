pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.components

// Wi-Fi and Bluetooth in one panel: a switch between their two lists (each
// with its own header and power switch), remembering the last one shown.
Column {
    id: root

    spacing: Tokens.spacing.normal

    ButtonGroup {
        width: parent.width
        current: ShellState.connectTab
        model: [
            {
                value: "wifi",
                icon: Network.icon,
                label: "Wi-Fi"
            },
            {
                value: "bluetooth",
                icon: BluetoothState.icon,
                label: "Bluetooth"
            }
        ]
        onSelected: v => ShellState.connectTab = v
    }

    Loader {
        width: parent.width
        sourceComponent: ShellState.connectTab === "bluetooth" ? bluetooth : wifi
        onLoaded: Choreo.cascade(item, 0)
    }

    Component {
        id: wifi

        NetworkPopout {}
    }

    Component {
        id: bluetooth

        BluetoothPopout {}
    }
}
