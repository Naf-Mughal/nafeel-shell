pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// The left edge of the frame, top to bottom:
//   [ bar.top ]      plugins' items (workspaces)          surface container
//   [ bar.actions ]  plugins' buttons (notifications ·
//                    clipboard · capture)                 secondary container
//   … bar.middle plugins …
//   [ tray ]                             surface container
//   [ sound · connections · battery ]    primary (each opens the bottom-left
//                                        corner: sound has brightness and now
//                                        playing, connections Wi-Fi and Bluetooth)
//   ( power )
// and the clock in the vertical middle.                            error container
// Every control previews its popout on hover; see BarControl.
Item {
    id: root

    property ShellScreen shellScreen

    Column {
        anchors.top: parent.top
        // The same inset as the sides, so the bar's ends match its edges.
        anchors.topMargin: (Tokens.barWidth - (Tokens.barWidth - Tokens.spacing.large)) / 2
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Tokens.spacing.normal

        BarGroup {
            id: topGroup

            visible: top.count > 0
            fill: Colours.palette.m3surfaceContainerHigh
            ink: Colours.palette.m3onSurface
            padding: 4

            PluginSlot {
                id: top

                slot: "bar.top"
                group: topGroup
                shellScreen: root.shellScreen
            }
        }

        BarGroup {
            id: actionsGroup

            // Nothing to hold while every action plugin is off.
            visible: actions.count > 0
            fill: Colours.palette.m3secondaryContainer
            ink: Colours.palette.m3onSecondaryContainer
            // The pill in the group's inverse (as the sound group's), so it
            // stands out on the capsule.
            pillFill: Colours.palette.m3onSecondaryContainer
            pillInk: Colours.palette.m3secondaryContainer

            PluginSlot {
                id: actions

                slot: "bar.actions"
                group: actionsGroup
                shellScreen: root.shellScreen
            }
        }

        PluginSlot {
            slot: "bar.middle"
            shellScreen: root.shellScreen
        }
    }

    Clock {
        anchors.centerIn: parent
    }

    Column {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: (Tokens.barWidth - (Tokens.barWidth - Tokens.spacing.large)) / 2
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Tokens.spacing.normal

        PluginSlot {
            slot: "bar.bottom"
            shellScreen: root.shellScreen
        }

        BarGroup {
            visible: tray.children.length > 1
            fill: Colours.palette.m3surfaceContainerHigh
            ink: Colours.palette.m3onSurface
            padding: 6

            Tray {
                id: tray

                width: parent.width
                shellScreen: root.shellScreen
            }
        }

        // Sound (with brightness and now playing), connections (Wi-Fi and
        // Bluetooth) and battery; each opens the bottom-left corner.
        BarGroup {
            fill: Colours.palette.m3primary
            ink: Colours.palette.m3onPrimary
            pillFill: Colours.palette.m3onPrimary
            pillInk: Colours.palette.m3primary

            BarControl {
                id: sound

                shellScreen: root.shellScreen
                popout: "sound"
                // The album art while something plays, else the speaker.
                icon: Media.playing && Media.art ? "" : Audio.muted ? "volume_off" : Audio.volume === 0 ? "volume_mute" : Audio.volume < 0.5 ? "volume_down" : "volume_up"
                alert: Audio.muted ? Colours.palette.m3error : "transparent"
                onRightClicked: Audio.toggleMute()
                onMiddleClicked: Media.togglePlaying()
                onScrolled: up => Audio.setVolume(Audio.volume + (up ? 0.05 : -0.05))

                ClippingRectangle {
                    visible: Media.playing && Media.art !== ""
                    width: 24
                    height: 24
                    radius: Tokens.rounding.small
                    color: "transparent"

                    Image {
                        anchors.fill: parent
                        source: Media.art
                        sourceSize: Qt.size(48, 48)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }
            }

            BarControl {
                shellScreen: root.shellScreen
                popout: "connect"
                icon: Network.icon
                // A dot while a Bluetooth device is connected.
                dot: BluetoothState.connected.length > 0
                onRightClicked: Network.toggleWifi()
            }

            BarControl {
                id: battery

                shellScreen: root.shellScreen
                visible: Power.hasBattery
                popout: "battery"
                alert: Power.low ? Colours.palette.m3error : "transparent"

                BatteryIcon {
                    ink: battery.ink
                    hole: battery.active ? Colours.palette.m3onPrimary : Colours.palette.m3primary
                }
            }
        }

        BarGroup {
            fill: Colours.palette.m3errorContainer
            ink: Colours.palette.m3onErrorContainer
            pillFill: Colours.palette.m3error
            pillInk: Colours.palette.m3onError
            radius: Tokens.rounding.small
            padding: 3

            BarControl {
                shellScreen: root.shellScreen
                popout: "session"
                icon: "power_settings_new"
            }
        }
    }
}
