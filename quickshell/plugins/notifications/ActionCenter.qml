pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// The action center (Windows-style, bottom right): notifications on top,
// then quick toggles, the volume and brightness sliders, and the clock with
// the session buttons at the bottom. Showing it marks notifications seen.
Item {
    id: root

    property string armed: ""

    Component.onCompleted: Notifs.markSeen()

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Timer {
        id: disarm

        interval: 4000
        onTriggered: root.armed = ""
    }

    Item {
        id: header

        width: parent.width
        height: 40

        Column {
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                text: "Notifications"
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }

            StyledText {
                text: Notifs.history.length > 0 ? `${Notifs.history.length} in history` : "All caught up"
                color: Colours.palette.m3onSurfaceVariant
                font.pixelSize: 11
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.spacing.small

            IconButton {
                icon: "do_not_disturb_on"
                filled: Notifs.dnd
                size: 36
                onClicked: Notifs.toggleDnd()
            }

            IconButton {
                icon: "clear_all"
                size: 36
                onClicked: Notifs.clear()
            }
        }
    }

    Scroller {
        id: list

        anchors.top: header.bottom
        anchors.topMargin: Tokens.spacing.normal
        anchors.bottom: controls.top
        anchors.bottomMargin: Tokens.spacing.normal
        width: parent.width
        contentHeight: cards.implicitHeight
        clip: true

        Column {
            id: cards

            width: parent.width
            spacing: Tokens.spacing.small

            Repeater {
                model: Notifs.history

                NotificationCard {
                    required property var modelData

                    width: cards.width
                    entry: modelData
                }
            }
        }

        EmptyState {
            anchors.centerIn: parent
            width: parent.width
            visible: Notifs.history.length === 0
            icon: "notifications_paused"
            title: "All quiet"
            hint: Notifs.dnd ? "Do not disturb is on" : "No messages have arrived"
        }
    }

    Column {
        id: controls

        anchors.bottom: parent.bottom
        width: parent.width
        spacing: Tokens.spacing.normal

        Grid {
            width: parent.width
            columns: 3
            spacing: Tokens.spacing.small

            readonly property real cell: (width - spacing * 2) / 3

            Tile {
                width: parent.cell
                icon: Network.icon
                label: "Wi-Fi"
                sublabel: Network.active?.name ?? (Network.wifiEnabled ? "On" : "Off")
                checked: Network.wifiEnabled
                onClicked: Network.toggleWifi()
            }
            Tile {
                width: parent.cell
                icon: BluetoothState.icon
                label: "Bluetooth"
                sublabel: BluetoothState.enabled ? "On" : "Off"
                checked: BluetoothState.enabled
                onClicked: BluetoothState.toggle()
            }
            Tile {
                width: parent.cell
                icon: Notifs.dnd ? "notifications_off" : "notifications"
                label: "Silent"
                sublabel: Notifs.dnd ? "On" : "Off"
                checked: Notifs.dnd
                onClicked: Notifs.toggleDnd()
            }
            Tile {
                width: parent.cell
                icon: "coffee"
                label: "Caffeine"
                sublabel: Display.caffeine ? "On" : "Off"
                checked: Display.caffeine
                onClicked: Display.toggleCaffeine()
            }
            Tile {
                width: parent.cell
                icon: "nightlight"
                label: "Night"
                sublabel: Display.nightLight ? "On" : "Off"
                checked: Display.nightLight
                onClicked: Display.toggleNightLight()
            }
            Tile {
                width: parent.cell
                icon: "dark_mode"
                label: "Dark"
                sublabel: Colours.light ? "Off" : "On"
                checked: !Colours.light
                onClicked: Display.toggleDarkMode()
            }
        }

        VolumeRow {
            width: parent.width
            icon: Audio.muted ? "volume_off" : "volume_up"
            muted: Audio.muted
            value: Audio.volume
            onToggleMute: Audio.toggleMute()
            onMoved: v => Audio.setVolume(v)
        }

        Row {
            width: parent.width
            visible: Brightness.available
            spacing: Tokens.spacing.small

            IconButton {
                icon: "light_mode"
                filled: true
                caption: Math.round(Brightness.level * 100)
            }

            StyledSlider {
                width: parent.width - 40 - Tokens.spacing.small
                value: Brightness.level
                onMoved: v => Brightness.set(v)
                Component.onCompleted: Brightness.watchers++
                Component.onDestruction: Brightness.watchers--
            }
        }

        Item {
            width: parent.width
            height: 44

            Column {
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    text: Time.time(clock.date)
                    font.pixelSize: 18
                    font.weight: Font.Bold
                }

                StyledText {
                    text: Qt.formatDate(clock.date, "dddd, MMM d")
                    color: Colours.palette.m3onSurfaceVariant
                    font.pixelSize: 11
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Tokens.spacing.small

                Repeater {
                    model: [
                        { action: "lock", icon: "lock", confirm: false },
                        { action: "logout", icon: "logout", confirm: true },
                        { action: "suspend", icon: "bedtime", confirm: false },
                        { action: "reboot", icon: "restart_alt", confirm: true },
                        { action: "shutdown", icon: "power_settings_new", confirm: true }
                    ]

                    IconButton {
                        required property var modelData

                        icon: root.armed === modelData.action ? "check" : modelData.icon
                        size: 40
                        filled: root.armed === modelData.action || modelData.action === "shutdown"
                        fillColour: Colours.palette.m3errorContainer
                        inkColour: Colours.palette.m3onErrorContainer
                        onClicked: {
                            if (modelData.confirm && root.armed !== modelData.action) {
                                root.armed = modelData.action;
                                disarm.restart();
                                return;
                            }
                            ShellState.close();
                            Session.run(modelData.action);
                        }
                    }
                }
            }
        }
    }
}
