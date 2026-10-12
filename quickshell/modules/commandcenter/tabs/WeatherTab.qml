pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// Weather from Noctalia's cache: now, the next twelve hours, and the week.
Item {
    id: root

    SystemClock {
        id: clock

        precision: SystemClock.Hours
    }

    StyledText {
        anchors.centerIn: parent
        visible: Weather.current === null
        text: "No weather yet: set a location in Noctalia's settings"
        color: Colours.palette.m3onSurfaceVariant
    }

    Column {
        visible: Weather.current !== null
        width: parent.width
        spacing: Tokens.spacing.normal

        StyledRect {
            width: parent.width
            height: 120
            radius: Tokens.rounding.large
            color: Colours.palette.m3primaryContainer

            MaterialIcon {
                id: now

                anchors.left: parent.left
                anchors.leftMargin: Tokens.spacing.large
                anchors.verticalCenter: parent.verticalCenter
                text: Weather.icon
                fill: 1
                size: 64
                color: Colours.palette.m3onPrimaryContainer
            }

            Column {
                anchors.left: now.right
                anchors.leftMargin: Tokens.spacing.large
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    text: `${Time.deg(Weather.temp)}  ${Weather.description}`
                    color: Colours.palette.m3onPrimaryContainer
                    font.family: Tokens.font.serif
                    font.pixelSize: 30
                    font.weight: Font.DemiBold
                }

                StyledText {
                    text: `${Weather.place} · feels ${Time.deg(Weather.current?.apparent_temperature_c ?? 0)} · humidity ${Weather.current?.relative_humidity_percent ?? 0}% · wind ${Time.speed(Weather.current?.wind_speed_kmh ?? 0)}`
                    color: Qt.alpha(Colours.palette.m3onPrimaryContainer, 0.85)
                    font.pixelSize: 12
                }
            }
        }

        SectionLabel {
            text: "Next hours"
        }

        Row {
            width: parent.width

            Repeater {
                model: Weather.hours.filter(h => new Date(h.time_iso) >= new Date(clock.date.getTime() - 3600000)).slice(0, 12)

                Column {
                    id: hour

                    required property var modelData

                    width: root.width / 12
                    spacing: 2

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Time.hour(new Date(hour.modelData.time_iso))
                        color: Colours.palette.m3onSurfaceVariant
                        font.pixelSize: 10
                    }

                    MaterialIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Weather.iconFor(hour.modelData.weather_code, hour.modelData.is_day)
                        size: 20
                        color: Colours.palette.m3onSurface
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Time.deg(hour.modelData.temperature_c)
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: (hour.modelData.precipitation_probability_percent ?? 0) > 0
                        text: `${hour.modelData.precipitation_probability_percent}%`
                        color: Colours.palette.m3tertiary
                        font.pixelSize: 10
                    }
                }
            }
        }

        SectionLabel {
            text: "This week"
        }

        Row {
            width: parent.width
            spacing: Tokens.spacing.small

            Repeater {
                model: Weather.days.slice(0, 7)

                StyledRect {
                    id: dayCard

                    required property var modelData
                    required property int index

                    width: (root.width - Tokens.spacing.small * 6) / 7
                    height: 108
                    radius: Tokens.rounding.normal
                    color: index === 0 ? Colours.palette.m3secondaryContainer : Colours.palette.m3surfaceContainerHigh

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: dayCard.index === 0 ? "Today" : Qt.formatDate(new Date(dayCard.modelData.date_iso + "T12:00"), "ddd")
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }

                        MaterialIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Weather.iconFor(dayCard.modelData.weather_code, true)
                            fill: 1
                            size: 24
                            color: Colours.palette.m3primary
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Time.deg(dayCard.modelData.temperature_max_c)
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Time.deg(dayCard.modelData.temperature_min_c)
                            color: Colours.palette.m3onSurfaceVariant
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }
    }
}
