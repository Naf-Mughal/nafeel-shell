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
        switchOnHover: true
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

    // Each list made the first time it's shown and then kept, the other
    // hidden: the tabs switch on hover, and making a list on every switch
    // (rows, icons, switches) cost frames. Hidden, Wi-Fi stops scanning (its
    // `visible`) and a Bluetooth scan started here stops (as it did when the
    // list went away).
    readonly property bool onBluetooth: ShellState.connectTab === "bluetooth"
    // Set, never bound: a binding (madeWifi: !onBluetooth) let the Wi-Fi
    // list go every time Bluetooth showed, and made it again on the way back.
    property bool madeWifi: false
    property bool madeBluetooth: false
    Component.onCompleted: {
        madeWifi = !onBluetooth;
        madeBluetooth = onBluetooth;
    }
    onOnBluetoothChanged: {
        if (onBluetooth)
            madeBluetooth = true;
        else
            madeWifi = true;
        Qt.callLater(() => Choreo.cascade(root.onBluetooth ? bluetoothList.item : wifiList.item, 0));
    }

    Loader {
        id: wifiList

        width: parent.width
        active: root.madeWifi
        visible: !root.onBluetooth
        sourceComponent: wifi
        onLoaded: Choreo.cascade(item, 0)
    }

    Loader {
        id: bluetoothList

        width: parent.width
        active: root.madeBluetooth
        visible: root.onBluetooth
        sourceComponent: bluetooth
        onLoaded: Choreo.cascade(item, 0)
        onVisibleChanged: {
            if (!visible && BluetoothState.adapter?.discovering)
                BluetoothState.adapter.discovering = false;
        }
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
