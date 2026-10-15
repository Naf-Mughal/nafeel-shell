pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// Weather from Noctalia's cache: now (with today's range, feels, humidity,
// wind), the next twelve hours as a curve, and the week as rows with each
// day's range on the week's scale (today's marks where it is now). Scrolls
// when the room is short, never spills.
Item {
    id: root

    SystemClock {
        id: clock

        precision: SystemClock.Hours
    }

    readonly property var hours: Weather.hours.filter(h => new Date(h.time_iso) >= new Date(clock.date.getTime() - 3600000)).slice(0, 12)
    readonly property var days: Weather.days.slice(0, 7)
    // The week's coldest and warmest (every day's bar is on this scale).
    readonly property real weekMin: days.length ? Math.min(...days.map(d => d.temperature_min_c)) : 0
    readonly property real weekMax: days.length ? Math.max(...days.map(d => d.temperature_max_c)) : 1
    // A day's chance of rain: its likeliest hour (the days carry none).
    function rainOf(dateIso: string): int {
        const hs = Weather.hours.filter(h => (h.time_iso ?? "").startsWith(dateIso));
        return hs.length ? Math.max(...hs.map(h => h.precipitation_probability_percent ?? 0)) : 0;
    }

    StyledText {
        anchors.centerIn: parent
        visible: Weather.current === null
        text: "No weather yet: set a location in Noctalia's settings"
        color: Colours.palette.m3onSurfaceVariant
    }

    Scroller {
        anchors.fill: parent
        visible: Weather.current !== null
        contentHeight: body.implicitHeight

        Column {
            id: body

            width: parent.width
            spacing: Tokens.spacing.normal

            // ── Now ──
            Surface {
                width: parent.width
                height: 104
                role: "primary"
                shape: "large"

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Tokens.spacing.large
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.spacing.large

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Weather.icon
                        fill: 1
                        size: 56
                        color: Colours.roleInk("primary", "soft")
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter

                        StyledText {
                            text: Time.deg(Weather.temp)
                            color: Colours.roleInk("primary", "soft")
                            font.family: Tokens.font.serif
                            font.pixelSize: 36
                        }
                        StyledText {
                            text: `${Weather.description} · ${Weather.place}`
                            color: Colours.roleSubInk("primary", "soft")
                            font.pixelSize: Tokens.font.small
                        }
                    }
                }

                // Today's range and the air, two by two.
                Grid {
                    anchors.right: parent.right
                    anchors.rightMargin: Tokens.spacing.large
                    anchors.verticalCenter: parent.verticalCenter
                    columns: 2
                    columnSpacing: Tokens.spacing.large
                    rowSpacing: 6

                    Repeater {
                        model: [["arrow_upward", Time.deg(root.days[0]?.temperature_max_c ?? 0), "high"], ["arrow_downward", Time.deg(root.days[0]?.temperature_min_c ?? 0), "low"], ["thermostat", Time.deg(Weather.current?.apparent_temperature_c ?? 0), "feels"], ["water_drop", `${Weather.current?.relative_humidity_percent ?? 0}%`, "humidity"], ["air", Time.speed(Weather.current?.wind_speed_kmh ?? 0), "wind"]].slice(0, 4)

                        Row {
                            required property var modelData

                            spacing: 4

                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: parent.modelData[0]
                                size: 15
                                color: Colours.roleSubInk("primary", "soft")
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: parent.modelData[1]
                                color: Colours.roleInk("primary", "soft")
                                font.pixelSize: Tokens.font.body
                                font.weight: Font.DemiBold
                            }
                            MicroLabel {
                                anchors.verticalCenter: parent.verticalCenter
                                text: parent.modelData[2]
                            }
                        }
                    }
                }
            }

            // ── The next hours: a curve, with the hour, its sky and its rain ──
            SectionLabel {
                text: "Next hours"
            }

            Item {
                id: hoursBox

                width: parent.width
                height: 96

                readonly property real step: width / Math.max(1, root.hours.length)
                readonly property real lo: root.hours.length ? Math.min(...root.hours.map(h => h.temperature_c)) : 0
                readonly property real hi: root.hours.length ? Math.max(...root.hours.map(h => h.temperature_c)) : 1
                function yOf(t: real): real {
                    return 30 - 22 * (t - lo) / Math.max(1, hi - lo);
                }

                Canvas {
                    id: curve

                    width: parent.width
                    height: 34
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const h = root.hours, s = hoursBox.step;
                        if (h.length < 2)
                            return;
                        const pts = h.map((x, i) => [s * i + s / 2, hoursBox.yOf(x.temperature_c)]);
                        ctx.beginPath();
                        ctx.moveTo(pts[0][0], pts[0][1]);
                        for (let i = 1; i < pts.length - 1; i++)
                            ctx.quadraticCurveTo(pts[i][0], pts[i][1], (pts[i][0] + pts[i + 1][0]) / 2, (pts[i][1] + pts[i + 1][1]) / 2);
                        ctx.lineTo(pts[pts.length - 1][0], pts[pts.length - 1][1]);
                        ctx.lineWidth = 2;
                        ctx.strokeStyle = Colours.palette.m3primary;
                        ctx.stroke();
                        for (const p of pts) {
                            ctx.beginPath();
                            ctx.arc(p[0], p[1], 2.5, 0, Math.PI * 2);
                            ctx.fillStyle = Colours.palette.m3primary;
                            ctx.fill();
                        }
                    }
                    Connections {
                        target: root

                        function onHoursChanged(): void {
                            curve.requestPaint();
                        }
                    }
                    Component.onCompleted: requestPaint()
                    onWidthChanged: requestPaint()
                }

                Row {
                    anchors.top: curve.bottom

                    Repeater {
                        model: root.hours

                        Column {
                            id: hour

                            required property var modelData

                            width: hoursBox.step
                            spacing: 1

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Time.deg(hour.modelData.temperature_c)
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }
                            MaterialIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Weather.iconFor(hour.modelData.weather_code, hour.modelData.is_day)
                                size: 18
                                color: Colours.palette.m3onSurface
                            }
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Time.hour(new Date(hour.modelData.time_iso))
                                color: Colours.palette.m3onSurfaceVariant
                                font.pixelSize: 10
                            }
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                opacity: (hour.modelData.precipitation_probability_percent ?? 0) > 0 ? 1 : 0
                                text: `${hour.modelData.precipitation_probability_percent ?? 0}%`
                                color: Colours.palette.m3tertiary
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }

            // ── The week: each day's range on the week's scale ──
            SectionLabel {
                text: "This week"
            }

            Column {
                width: parent.width
                spacing: 2

                Repeater {
                    model: root.days

                    Surface {
                        id: day

                        required property var modelData
                        required property int index
                        readonly property real lo: modelData.temperature_min_c
                        readonly property real hi: modelData.temperature_max_c
                        readonly property real span: Math.max(1, root.weekMax - root.weekMin)

                        width: parent.width
                        height: 30
                        role: index === 0 ? "secondary" : "paper"
                        emphasis: index === 0 ? "soft" : "ghost"
                        shape: "small"

                        StyledText {
                            id: name

                            x: Tokens.spacing.normal
                            width: 54
                            anchors.verticalCenter: parent.verticalCenter
                            text: day.index === 0 ? "Today" : Qt.formatDate(new Date(day.modelData.date_iso + "T12:00"), "ddd")
                            color: day.ink
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                        MaterialIcon {
                            id: sky

                            anchors.left: name.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: Weather.iconFor(day.modelData.weather_code, true)
                            fill: 1
                            size: 18
                            color: Colours.palette.m3primary
                        }
                        StyledText {
                            id: rain

                            anchors.left: sky.right
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 34
                            readonly property int chance: root.rainOf(day.modelData.date_iso)
                            text: chance > 0 ? `${chance}%` : ""
                            color: Colours.palette.m3tertiary
                            font.pixelSize: 10
                        }
                        StyledText {
                            id: low

                            anchors.left: rain.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 34
                            horizontalAlignment: Text.AlignRight
                            text: Time.deg(day.lo)
                            color: day.subInk
                            font.pixelSize: 12
                        }

                        // The range, on the week's scale; today's marks now.
                        Item {
                            id: bar

                            anchors.left: low.right
                            anchors.leftMargin: Tokens.spacing.normal
                            anchors.right: high.left
                            anchors.rightMargin: Tokens.spacing.normal
                            anchors.verticalCenter: parent.verticalCenter
                            height: 6

                            StyledRect {
                                anchors.fill: parent
                                radius: 3
                                color: Colours.roleFill("paper", "soft", 4)
                            }
                            StyledRect {
                                x: parent.width * (day.lo - root.weekMin) / day.span
                                width: Math.max(6, parent.width * (day.hi - day.lo) / day.span)
                                height: parent.height
                                radius: 3
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop {
                                        position: 0
                                        color: Colours.palette.m3tertiary
                                    }
                                    GradientStop {
                                        position: 1
                                        color: Colours.palette.m3primary
                                    }
                                }
                            }
                            Rectangle {
                                visible: day.index === 0
                                x: parent.width * (Math.max(day.lo, Math.min(day.hi, Weather.temp)) - root.weekMin) / day.span - width / 2
                                anchors.verticalCenter: parent.verticalCenter
                                width: 10
                                height: 10
                                radius: 5
                                color: Colours.palette.m3onSurface
                                border.width: 2
                                border.color: Colours.palette.m3surface
                            }
                        }

                        StyledText {
                            id: high

                            anchors.right: parent.right
                            anchors.rightMargin: Tokens.spacing.normal
                            anchors.verticalCenter: parent.verticalCenter
                            width: 34
                            horizontalAlignment: Text.AlignRight
                            text: Time.deg(day.hi)
                            color: day.ink
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }
    }
}
