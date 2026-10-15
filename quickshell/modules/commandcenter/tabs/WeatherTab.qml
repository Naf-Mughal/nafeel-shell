pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// Weather from Noctalia's cache (after Caelestia's tab, in the shell's ink):
// where and when with the sun's rise and set; now, large, beside four
// details; the next twelve hours as a curve with their rain; the week as
// rows with each day's range on the week's scale. Scrolls when the room is
// short, never spills.
Item {
    id: root

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    readonly property var hours: Weather.hours.filter(h => new Date(h.time_iso) >= new Date(clock.date.getTime() - 3600000)).slice(0, 12)
    readonly property var days: Weather.days.slice(0, 7)
    readonly property var today: days[0] ?? null
    readonly property real weekMin: days.length ? Math.min(...days.map(d => d.temperature_min_c)) : 0
    readonly property real weekMax: days.length ? Math.max(...days.map(d => d.temperature_max_c)) : 1
    // Two columns where there's room (the dashboard), stacked where not.
    readonly property bool wide: width > 720

    // A day's chance of rain: its likeliest hour (the days carry none).
    function rainOf(dateIso: string): int {
        const hs = Weather.hours.filter(h => (h.time_iso ?? "").startsWith(dateIso));
        return hs.length ? Math.max(...hs.map(h => h.precipitation_probability_percent ?? 0)) : 0;
    }

    function clockOf(iso: string): string {
        return iso ? Qt.formatTime(new Date(iso), Time.h24 ? "HH:mm" : "h:mm AP") : "—";
    }

    // A detail: an icon in its own colour, a label, a value.
    component Detail: Surface {
        id: detail

        property string icon
        property string label
        property string value
        property color colour
        property real iconRotation: 0

        level: 3
        implicitHeight: 64

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Tokens.spacing.large
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.spacing.normal

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: detail.icon
                fill: 1
                size: 24
                color: detail.colour
                rotation: detail.iconRotation
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter

                MicroLabel {
                    text: detail.label
                }
                StyledText {
                    text: detail.value
                    color: Colours.palette.m3onSurface
                    font.pixelSize: Tokens.font.row
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    StyledText {
        anchors.centerIn: parent
        visible: Weather.current === null
        text: "No weather yet: set a location in Settings → Weather"
        color: Colours.palette.m3onSurfaceVariant
    }

    Scroller {
        anchors.fill: parent
        visible: Weather.current !== null
        contentHeight: body.implicitHeight

        Column {
            id: body

            width: parent.width
            spacing: Tokens.spacing.large

            // ── Where and when, the sun ──
            Item {
                width: parent.width
                height: where.implicitHeight

                Column {
                    id: where

                    GlossTitle {
                        text: Weather.place.split(",")[0] || "Weather"
                        gloss: "天象"
                    }
                    MicroLabel {
                        text: Qt.formatDate(clock.date, "dddd · d MMMM")
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.spacing.huge

                    Repeater {
                        model: [["wb_twilight", "sunrise", root.clockOf(root.today?.sunrise_iso)], ["bedtime", "sunset", root.clockOf(root.today?.sunset_iso)]]

                        Row {
                            required property var modelData

                            spacing: Tokens.spacing.small

                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: parent.modelData[0]
                                size: 22
                                color: Colours.palette.m3tertiary
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter

                                MicroLabel {
                                    text: parent.parent.modelData[1]
                                }
                                StyledText {
                                    text: parent.parent.modelData[2]
                                    color: Colours.palette.m3onSurface
                                    font.pixelSize: Tokens.font.body
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }
                }
            }

            // ── Now, large, beside four details ──
            Grid {
                width: parent.width
                columns: root.wide ? 2 : 1
                columnSpacing: Tokens.spacing.normal
                rowSpacing: Tokens.spacing.normal

                Surface {
                    width: root.wide ? (parent.width - parent.columnSpacing) * 0.48 : parent.width
                    height: 140
                    role: "primary"
                    shape: "large"

                    Row {
                        anchors.centerIn: parent
                        spacing: Tokens.spacing.large

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Weather.icon
                            fill: 1
                            size: 76
                            color: Colours.roleInk("primary", "soft")
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: -4

                            StyledText {
                                text: Time.deg(Weather.temp)
                                color: Colours.roleInk("primary", "soft")
                                font.family: Tokens.font.serif
                                font.pixelSize: 54
                            }
                            StyledText {
                                text: Weather.description
                                color: Colours.roleSubInk("primary", "soft")
                                font.pixelSize: Tokens.font.body
                            }
                            StyledText {
                                text: root.today ? `${Time.deg(root.today.temperature_max_c)} / ${Time.deg(root.today.temperature_min_c)}` : ""
                                color: Colours.roleSubInk("primary", "soft")
                                font.pixelSize: Tokens.font.small
                            }
                        }
                    }
                }

                Grid {
                    width: root.wide ? (parent.width - parent.columnSpacing) * 0.52 : parent.width
                    columns: 2
                    spacing: Tokens.spacing.normal

                    Detail {
                        width: (parent.width - parent.spacing) / 2
                        icon: "thermostat"
                        label: "feels like"
                        value: Time.deg(Weather.current?.apparent_temperature_c ?? 0)
                        colour: Colours.palette.m3primary
                    }
                    Detail {
                        width: (parent.width - parent.spacing) / 2
                        icon: "water_drop"
                        label: "humidity"
                        value: `${Weather.current?.relative_humidity_percent ?? 0}%`
                        colour: Colours.palette.m3secondary
                    }
                    Detail {
                        width: (parent.width - parent.spacing) / 2
                        icon: "navigation"
                        // The arrow points where the wind goes.
                        iconRotation: ((Weather.current?.wind_direction_deg ?? 0) + 180) % 360
                        label: "wind"
                        value: Time.speed(Weather.current?.wind_speed_kmh ?? 0)
                        colour: Colours.palette.m3tertiary
                    }
                    Detail {
                        width: (parent.width - parent.spacing) / 2
                        icon: "light_mode"
                        label: "uv index"
                        value: `${Math.round(Weather.current?.uv_index ?? 0)}`
                        colour: (Weather.current?.uv_index ?? 0) >= 6 ? Colours.palette.m3error : Colours.palette.m3tertiary
                    }
                }
            }

            // ── The next hours ──
            Surface {
                width: parent.width
                height: hoursCol.implicitHeight + Tokens.spacing.large * 2
                level: 3

                Column {
                    id: hoursCol

                    x: Tokens.spacing.large
                    y: Tokens.spacing.large
                    width: parent.width - Tokens.spacing.large * 2
                    spacing: Tokens.spacing.small

                    SectionLabel {
                        text: "Next hours"
                    }

                    Item {
                        id: hoursBox

                        width: parent.width
                        height: 128

                        readonly property real step: width / Math.max(1, root.hours.length)
                        readonly property real lo: root.hours.length ? Math.min(...root.hours.map(h => h.temperature_c)) : 0
                        readonly property real hi: root.hours.length ? Math.max(...root.hours.map(h => h.temperature_c)) : 1
                        // The curve's band: 18 px for the labels above, 40 tall.
                        function yOf(t: real): real {
                            return 58 - 40 * (t - lo) / Math.max(1, hi - lo);
                        }

                        Canvas {
                            id: curve

                            width: parent.width
                            height: 72
                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.reset();
                                const h = root.hours, s = hoursBox.step;
                                if (h.length < 2)
                                    return;
                                const pts = h.map((x, i) => [s * i + s / 2, hoursBox.yOf(x.temperature_c)]);
                                const path = () => {
                                    ctx.moveTo(pts[0][0], pts[0][1]);
                                    for (let i = 1; i < pts.length - 1; i++)
                                        ctx.quadraticCurveTo(pts[i][0], pts[i][1], (pts[i][0] + pts[i + 1][0]) / 2, (pts[i][1] + pts[i + 1][1]) / 2);
                                    ctx.lineTo(pts[pts.length - 1][0], pts[pts.length - 1][1]);
                                };
                                // A soft wash under the curve.
                                ctx.beginPath();
                                path();
                                ctx.lineTo(pts[pts.length - 1][0], height);
                                ctx.lineTo(pts[0][0], height);
                                ctx.closePath();
                                const g = ctx.createLinearGradient(0, 0, 0, height);
                                g.addColorStop(0, Qt.alpha(Colours.palette.m3primary, 0.22));
                                g.addColorStop(1, Qt.alpha(Colours.palette.m3primary, 0));
                                ctx.fillStyle = g;
                                ctx.fill();
                                ctx.beginPath();
                                path();
                                ctx.lineWidth = 2;
                                ctx.strokeStyle = Colours.palette.m3primary;
                                ctx.stroke();
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

                        // Each hour: its temperature over the curve, its sky and
                        // time under it, its rain as a bar.
                        Repeater {
                            model: root.hours

                            Item {
                                id: hour

                                required property var modelData
                                required property int index
                                readonly property int rain: modelData.precipitation_probability_percent ?? 0

                                x: hoursBox.step * index
                                width: hoursBox.step
                                height: hoursBox.height

                                StyledText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: hoursBox.yOf(hour.modelData.temperature_c) - 18
                                    text: Time.deg(hour.modelData.temperature_c)
                                    color: Colours.palette.m3onSurface
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: hoursBox.yOf(hour.modelData.temperature_c) - 3
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: Colours.palette.m3primary
                                }
                                Column {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: 76
                                    spacing: 2

                                    MaterialIcon {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: Weather.iconFor(hour.modelData.weather_code, hour.modelData.is_day)
                                        size: 18
                                        color: Colours.palette.m3onSurfaceVariant
                                    }
                                    StyledText {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: hour.index === 0 ? "now" : Time.hour(new Date(hour.modelData.time_iso))
                                        color: Colours.palette.m3onSurfaceVariant
                                        font.pixelSize: 10
                                    }
                                    // Rain: a bar as likely as it is.
                                    StyledRect {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: Math.max(4, (hoursBox.step - 14) * hour.rain / 100)
                                        height: 3
                                        radius: 1.5
                                        color: Colours.palette.m3tertiary
                                        opacity: hour.rain > 0 ? 1 : 0
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── The week ──
            Surface {
                width: parent.width
                height: weekCol.implicitHeight + Tokens.spacing.large * 2
                level: 3

                Column {
                    id: weekCol

                    x: Tokens.spacing.large
                    y: Tokens.spacing.large
                    width: parent.width - Tokens.spacing.large * 2
                    spacing: 2

                    SectionLabel {
                        text: "This week"
                    }

                    Repeater {
                        model: root.days

                        Item {
                            id: day

                            required property var modelData
                            required property int index
                            readonly property real lo: modelData.temperature_min_c
                            readonly property real hi: modelData.temperature_max_c
                            readonly property real span: Math.max(1, root.weekMax - root.weekMin)
                            readonly property int rain: root.rainOf(modelData.date_iso)

                            width: weekCol.width
                            height: 34

                            StyledText {
                                id: name

                                width: 64
                                anchors.verticalCenter: parent.verticalCenter
                                text: day.index === 0 ? "Today" : Qt.formatDate(new Date(day.modelData.date_iso + "T12:00"), "dddd")
                                color: Colours.palette.m3onSurface
                                font.pixelSize: 12
                                font.weight: day.index === 0 ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                            }
                            MaterialIcon {
                                id: sky

                                anchors.left: name.right
                                anchors.leftMargin: Tokens.spacing.small
                                anchors.verticalCenter: parent.verticalCenter
                                text: Weather.iconFor(day.modelData.weather_code, true)
                                fill: 1
                                size: 20
                                color: Colours.palette.m3primary
                            }
                            StyledText {
                                id: rainText

                                anchors.left: sky.right
                                anchors.leftMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                width: 36
                                text: day.rain >= 10 ? `${day.rain}%` : ""
                                color: Colours.palette.m3tertiary
                                font.pixelSize: 11
                            }
                            StyledText {
                                id: low

                                anchors.left: rainText.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 34
                                horizontalAlignment: Text.AlignRight
                                text: Time.deg(day.lo)
                                color: Colours.palette.m3onSurfaceVariant
                                font.pixelSize: 12
                            }

                            // The range, on the week's scale; today's marks now.
                            Item {
                                anchors.left: low.right
                                anchors.leftMargin: Tokens.spacing.normal
                                anchors.right: high.left
                                anchors.rightMargin: Tokens.spacing.normal
                                anchors.verticalCenter: parent.verticalCenter
                                height: 4

                                StyledRect {
                                    anchors.fill: parent
                                    radius: 2
                                    color: Qt.alpha(Colours.palette.m3onSurface, 0.08)
                                }
                                StyledRect {
                                    x: parent.width * (day.lo - root.weekMin) / day.span
                                    width: Math.max(4, parent.width * (day.hi - day.lo) / day.span)
                                    height: parent.height
                                    radius: 2
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
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: Colours.palette.m3onSurface
                                    border.width: 2
                                    border.color: Colours.palette.m3surfaceContainer
                                }
                            }

                            StyledText {
                                id: high

                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 34
                                horizontalAlignment: Text.AlignRight
                                text: Time.deg(day.hi)
                                color: Colours.palette.m3onSurface
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }

                            Hairline {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                visible: day.index < root.days.length - 1
                                opacity: 0.5
                            }
                        }
                    }
                }
            }
        }
    }
}
