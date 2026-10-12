pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.UPower
import qs.config
import qs.services
import qs.components

// Home: who and where on the wallpaper, then what's playing, the time and
// today's weather (with the next hours), and the quick toggles.
Item {
    id: root

    readonly property real gap: Tokens.spacing.normal

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    // Hero: the wallpaper, dimmed, with name, user@host and uptime.
    ClippingRectangle {
        id: hero

        width: parent.width
        height: 150
        radius: Tokens.rounding.large
        color: Colours.palette.m3surfaceContainerHigh

        Image {
            anchors.fill: parent
            source: Session.wallpaper ? "file://" + Session.wallpaper : ""
            sourceSize: Qt.size(1280, 400)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: Qt.alpha(Colours.palette.m3surface, 0.85)
                }
                GradientStop {
                    position: 0.7
                    color: Qt.alpha(Colours.palette.m3surface, 0.15)
                }
            }
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Tokens.spacing.large * 1.5
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.spacing.large

            StyledRect {
                width: 72
                height: 72
                radius: Tokens.rounding.large
                color: Colours.palette.m3primary

                StyledText {
                    anchors.centerIn: parent
                    text: (Session.realName || Session.user).charAt(0).toUpperCase()
                    color: Colours.palette.m3onPrimary
                    font.pixelSize: 32
                    font.weight: Font.Bold
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                StyledText {
                    text: Session.realName || Session.user
                    font.family: Tokens.font.serif
                    font.pixelSize: 24
                    font.weight: Font.DemiBold
                }

                StyledText {
                    text: `${Session.user}@${Session.host}`
                    color: Colours.palette.m3onSurfaceVariant
                    font.pixelSize: 13
                }

                StyledText {
                    text: `Up ${Session.formatUptime()}`
                    color: Colours.palette.m3onSurfaceVariant
                    font.pixelSize: 13
                }
            }
        }
    }

    Row {
        anchors.top: hero.bottom
        anchors.topMargin: root.gap
        anchors.bottom: parent.bottom
        width: parent.width
        spacing: root.gap

        Column {
            width: (parent.width - root.gap) * 0.56
            height: parent.height
            spacing: root.gap

            // What's playing.
            Surface {
                width: parent.width
                height: (parent.height - root.gap) / 2
                shape: "large"
                level: 3

                ClippingRectangle {
                    id: art

                    anchors.left: parent.left
                    anchors.leftMargin: Tokens.spacing.normal
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.height - Tokens.spacing.normal * 2
                    height: width
                    radius: Tokens.rounding.normal
                    color: Colours.palette.m3surfaceContainerHighest

                    Image {
                        anchors.fill: parent
                        source: Media.art
                        sourceSize: Qt.size(200, 200)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: !Media.art
                        text: "music_note"
                        size: 32
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }

                Column {
                    anchors.left: art.right
                    anchors.leftMargin: Tokens.spacing.normal
                    anchors.right: parent.right
                    anchors.rightMargin: Tokens.spacing.normal
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.spacing.small

                    StyledText {
                        width: parent.width
                        text: Media.title || "Nothing playing"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    StyledText {
                        width: parent.width
                        text: Media.artist
                        visible: text !== ""
                        color: Colours.palette.m3onSurfaceVariant
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    Row {
                        visible: Media.active !== null
                        spacing: Tokens.spacing.small

                        IconButton {
                            icon: "skip_previous"
                            size: 32
                            onClicked: Media.active?.previous()
                        }
                        IconButton {
                            icon: Media.playing ? "pause" : "play_arrow"
                            size: 32
                            filled: true
                            fillColour: Colours.palette.m3primary
                            inkColour: Colours.palette.m3onPrimary
                            onClicked: Media.togglePlaying()
                        }
                        IconButton {
                            icon: "skip_next"
                            size: 32
                            onClicked: Media.active?.next()
                        }
                    }
                }
            }

            // The time, and today's weather with the next hours.
            Surface {
                width: parent.width
                height: (parent.height - root.gap) / 2
                shape: "large"
                level: 3

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: Tokens.spacing.large
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                        spacing: 4

                        StyledText {
                            text: Time.time(clock.date).split(" ")[0]
                            font.family: Tokens.font.serif
                            font.pixelSize: 38
                            font.weight: Font.DemiBold
                        }

                        StyledText {
                            anchors.baseline: parent.children[0].baseline
                            visible: text !== ""
                            text: Time.meridiem(clock.date)
                            color: Colours.palette.m3onSurfaceVariant
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }
                    }

                    StyledText {
                        text: Qt.formatDate(clock.date, "ddd, MMM d")
                        color: Colours.palette.m3onSurfaceVariant
                        font.pixelSize: 12
                    }

                    // The double-hour, in the xianxia voice.
                    Row {
                        spacing: Tokens.spacing.small
                        topPadding: 2

                        StyledText {
                            text: Xian.shichen(clock.date).zh
                            color: Colours.palette.m3primary
                            font.family: Tokens.font.cjk
                            font.pixelSize: Tokens.font.body
                        }

                        MicroLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Xian.shichen(clock.date).en
                        }
                    }
                }

                Column {
                    anchors.right: parent.right
                    anchors.rightMargin: Tokens.spacing.large
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Weather.current !== null
                    spacing: 2

                    Row {
                        anchors.right: parent.right
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: Weather.icon
                            fill: 1
                            size: 26
                            color: Colours.palette.m3primary
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Time.deg(Weather.temp)
                            font.pixelSize: 22
                            font.weight: Font.DemiBold
                        }
                    }

                    StyledText {
                        anchors.right: parent.right
                        text: Weather.days[0] ? `${Weather.description} · ${Time.deg(Weather.days[0].temperature_max_c)} / ${Time.deg(Weather.days[0].temperature_min_c)}` : Weather.description
                        color: Colours.palette.m3onSurfaceVariant
                        font.pixelSize: 11
                    }

                    Row {
                        anchors.right: parent.right
                        spacing: Tokens.spacing.normal

                        Repeater {
                            // The next three hours.
                            model: Weather.hours.filter(h => new Date(h.time_iso) > clock.date).slice(0, 3)

                            Column {
                                id: hour

                                required property var modelData

                                StyledText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Time.hour(new Date(hour.modelData.time_iso))
                                    color: Colours.palette.m3onSurfaceVariant
                                    font.pixelSize: 10
                                }

                                StyledText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Time.deg(hour.modelData.temperature_c)
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }
                }
            }
        }

        // Quick toggles.
        Grid {
            width: (parent.width - root.gap) * 0.44
            columns: 2
            spacing: root.gap

            readonly property real cell: (width - root.gap) / 2
            readonly property real cellHeight: (parent.height - root.gap * 2) / 3

            Tile {
                width: parent.cell
                height: parent.cellHeight
                icon: Network.icon
                label: "Wi-Fi"
                sublabel: Network.active?.name ?? (Network.wifiEnabled ? "On" : "Off")
                checked: Network.wifiEnabled
                onClicked: Network.toggleWifi()
            }
            Tile {
                width: parent.cell
                height: parent.cellHeight
                icon: BluetoothState.icon
                label: "Bluetooth"
                sublabel: BluetoothState.connected[0]?.name ?? (BluetoothState.enabled ? "On" : "Off")
                checked: BluetoothState.enabled
                onClicked: BluetoothState.toggle()
            }
            Tile {
                width: parent.cell
                height: parent.cellHeight
                icon: "coffee"
                label: "Caffeine"
                sublabel: Display.caffeine ? "Awake" : "Off"
                checked: Display.caffeine
                onClicked: Display.toggleCaffeine()
            }
            Tile {
                width: parent.cell
                height: parent.cellHeight
                icon: "nightlight"
                label: "Night light"
                sublabel: Display.nightLight ? "On" : "Off"
                checked: Display.nightLight
                onClicked: Display.toggleNightLight()
            }
            Tile {
                // The notifications plugin's (absent while it's off).
                readonly property var notifs: Plugins.instance("notifications")?.notifs ?? null

                visible: notifs !== null
                width: parent.cell
                height: parent.cellHeight
                icon: (notifs?.dnd ?? false) ? "notifications_off" : "notifications"
                label: "Do not disturb"
                sublabel: (notifs?.dnd ?? false) ? "On" : "Off"
                checked: notifs?.dnd ?? false
                onClicked: notifs.toggleDnd()
            }
            Tile {
                readonly property var names: ["Power saver", "Balanced", "Performance"]

                width: parent.cell
                height: parent.cellHeight
                icon: PowerProfiles.profile === PowerProfile.PowerSaver ? "eco" : PowerProfiles.profile === PowerProfile.Performance ? "speed" : "balance"
                label: "Power"
                sublabel: names[PowerProfiles.profile] ?? ""
                checked: PowerProfiles.profile !== PowerProfile.Balanced
                onClicked: PowerProfiles.profile = PowerProfiles.profile === PowerProfile.Balanced ? PowerProfile.PowerSaver : PowerProfiles.profile === PowerProfile.PowerSaver && PowerProfiles.hasPerformanceProfile ? PowerProfile.Performance : PowerProfile.Balanced
            }
        }
    }
}
