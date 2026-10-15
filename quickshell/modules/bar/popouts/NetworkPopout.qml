pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// Wi-Fi: master switch, the current connection as a hero card, then the
// networks in range. Saved and open networks connect on click; a new secured
// one unfolds a password field in place.
Panel {
    id: root

    // The network whose password field is open.
    property string asking: ""


    // Scans only while the list shows: counted from its making, the panel
    // being made ahead (warm) kept Wi-Fi scanning all the time (battery, and
    // a list re-sorted every few seconds behind whatever was animating).
    property bool scanning: (visible && (ShellState.pinned === "bar:connect" || ShellState.previewed === "bar:connect")) || ShellState.grabbing === "bar:connect"
    onScanningChanged: Network.scanners += scanning ? 1 : -1

    // The networks shown: what the scan found, taken in only while no panel
    // moves (rows coming and going grew or shrank the popout in the middle
    // of its open or close, the scan starting and stopping with them).
    // New rows come one a frame (each is a few ms to make; several at
    // once held a frame of the popout growing to fit them).
    property var listed: []
    readonly property var found: Network.networks.filter(n => !n.connected)
    readonly property bool still: ShellState.moving === 0 && ShellState.grabbing === ""
    function takeIn(): void {
        if (!still)
            return;
        const have = new Set(listed);
        const fresh = found.filter(n => !have.has(n));
        // Gone ones leave and the order follows the scan at once; new ones
        // join one at a time.
        const next = found.filter(n => have.has(n));
        if (fresh.length > 0) {
            next.splice(found.indexOf(fresh[0]) <= next.length ? found.indexOf(fresh[0]) : next.length, 0, fresh[0]);
            trickle.restart();
        }
        listed = next;
    }
    onFoundChanged: takeIn()
    onStillChanged: takeIn()

    Timer {
        id: trickle

        interval: 34
        onTriggered: root.takeIn()
    }
    Component.onCompleted: {
        listed = found;
        if (scanning)
            Network.scanners++;
    }
    Component.onDestruction: {
        if (scanning)
            Network.scanners--;
    }

    PanelHeader {
        width: parent.width
        gloss: Xian.gloss.network
        icon: Network.icon
        title: "Wi-Fi"
        subtitle: !Network.wifiEnabled ? "Off" : Network.active ? "Connected" : "Not connected"

        StyledSwitch {
            checked: Network.wifiEnabled
            onToggled: Network.toggleWifi()
        }
    }

    // Wired or the connected Wi-Fi network.
    Surface {
        width: parent.width
        height: 72
        visible: Network.wired !== null || Network.active !== null
        role: "primary"
        shape: "large"

        MaterialIcon {
            id: heroIcon

            anchors.left: parent.left
            anchors.leftMargin: Tokens.spacing.large
            anchors.verticalCenter: parent.verticalCenter
            text: Network.wired ? "lan" : Network.signalIcon(Network.signal)
            fill: 1
            size: 28
            color: Colours.palette.m3onPrimaryContainer
        }

        Column {
            anchors.left: heroIcon.right
            anchors.leftMargin: Tokens.spacing.normal
            anchors.right: disconnect.left
            anchors.rightMargin: Tokens.spacing.small
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                width: parent.width
                text: Network.wired ? "Ethernet" : (Network.active?.name ?? "")
                color: Colours.palette.m3onPrimaryContainer
                font.pixelSize: 15
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                text: Network.wired ? (Network.wired.name ?? "") : `Connected · ${Math.round(Network.signal * 100)}%`
                color: Qt.alpha(Colours.palette.m3onPrimaryContainer, 0.8)
                font.pixelSize: 12
            }
        }

        IconButton {
            id: disconnect

            anchors.right: parent.right
            anchors.rightMargin: Tokens.spacing.normal
            anchors.verticalCenter: parent.verticalCenter
            visible: Network.active !== null && Network.wired === null
            icon: "link_off"
            size: 36
            onClicked: Network.active?.disconnect()
        }
    }

    EmptyState {
        width: parent.width
        visible: !Network.wifiEnabled && Network.wired === null
        icon: "wifi_off"
        title: "Wi-Fi is off"
        hint: "Turn it on to see networks nearby"
        actionText: "Turn on"
        onAction: Network.toggleWifi()
    }

    SectionLabel {
        visible: Network.wifiEnabled
        text: "Networks"
    }

    Scroller {
        width: parent.width
        height: Math.min(list.implicitHeight, 300)
        visible: Network.wifiEnabled
        contentHeight: list.implicitHeight
        clip: true

        // Hover only: the network in use isn't in this list.
        ListGoo {
            id: networksGoo

            anchors.fill: list
            container: list
            hoverOnly: true
        }

        Column {
            id: list

            width: parent.width
            spacing: 2

            StyledText {
                visible: Network.networks.filter(n => !n.connected).length === 0
                text: "Searching…"
                color: Colours.palette.m3onSurfaceVariant
                font.pixelSize: 12
                padding: Tokens.spacing.small
            }

            Repeater {
                // Diffed (ScriptModel): a new array (a signal strength, a stream
                // coming or going) moves or adds rows; rebuilding every row held the GUI
                // thread past a refresh, dropping a frame of whatever was animating.
                model: ScriptModel {
                    values: root.listed
                }
                Column {
                    id: entry

                    required property var modelData
                    readonly property bool open: Network.isOpen(modelData)

                    width: list.width
                    spacing: Tokens.spacing.small

                    ListRow {
                        width: parent.width
                        goo: networksGoo
                        icon: Network.signalIcon(entry.modelData.signalStrength)
                        title: entry.modelData.name
                        subtitle: entry.modelData.stateChanging ? "Connecting…" : entry.modelData.known ? "Saved" : entry.open ? "Open" : "Secured"
                        onClicked: {
                            if (entry.modelData.known || entry.open) {
                                entry.modelData.connect();
                            } else {
                                root.asking = root.asking === entry.modelData.name ? "" : entry.modelData.name;
                                if (root.asking)
                                    Qt.callLater(() => password.focusInput());
                            }
                        }

                        MaterialIcon {
                            visible: !entry.open
                            text: "lock"
                            size: 16
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }

                    Row {
                        width: parent.width
                        visible: root.asking === entry.modelData.name
                        spacing: Tokens.spacing.small

                        TextField {
                            id: password

                            width: parent.width - 44 - Tokens.spacing.small
                            placeholder: "Password"
                            echoMode: TextInput.Password
                            onAccepted: {
                                entry.modelData.connectWithPsk(text);
                                root.asking = "";
                            }
                        }

                        IconButton {
                            icon: "arrow_forward"
                            filled: true
                            fillColour: Colours.palette.m3primary
                            inkColour: Colours.palette.m3onPrimary
                            size: 44
                            onClicked: password.accepted()
                        }
                    }
                }
            }
        }
    }
}
