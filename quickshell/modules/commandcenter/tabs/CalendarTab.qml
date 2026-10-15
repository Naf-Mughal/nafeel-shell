pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// A month at a time, Monday first, today highlighted; days with events
// dotted. With `agenda` (the command center), the picked day's events beside
// the month: add one (a title, an optional time; a timed one reminds 10 min
// before), remove one.
Item {
    id: root

    property date month: new Date(new Date().getFullYear(), new Date().getMonth(), 1)
    readonly property date today: clock.date
    property bool agenda: false
    property string picked: Events.iso(new Date())
    readonly property var pickedEvents: Events.on(picked)

    // The 42 days shown (six weeks from the Monday on or before the 1st).
    readonly property var days: {
        const first = new Date(month.getFullYear(), month.getMonth(), 1);
        const start = new Date(first);
        start.setDate(1 - ((first.getDay() + 6) % 7));
        return Array.from({
            length: 42
        }, (_, i) => new Date(start.getFullYear(), start.getMonth(), start.getDate() + i));
    }

    function shift(by: int): void {
        month = new Date(month.getFullYear(), month.getMonth() + by, 1);
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Row {
        id: header

        width: grid.width
        spacing: Tokens.spacing.small

        StyledText {
            width: parent.width - 3 * (40 + Tokens.spacing.small)
            anchors.verticalCenter: parent.verticalCenter
            text: `${Qt.formatDate(root.month, "MMMM yyyy")}  ${Xian.numeral(root.month.getMonth() + 1)}月`
            font.family: Tokens.font.serif
            font.pixelSize: 24
            font.weight: Font.DemiBold
        }

        IconButton {
            icon: "chevron_left"
            onClicked: root.shift(-1)
        }
        IconButton {
            icon: "today"
            onClicked: root.month = new Date(root.today.getFullYear(), root.today.getMonth(), 1)
        }
        IconButton {
            icon: "chevron_right"
            onClicked: root.shift(1)
        }
    }

    Grid {
        id: grid

        anchors.top: header.bottom
        anchors.topMargin: Tokens.spacing.large
        width: root.agenda ? parent.width * 0.58 : parent.width
        columns: 7

        readonly property real cell: width / 7
        readonly property real cellHeight: (root.height - header.height - Tokens.spacing.large - 28) / 6

        Repeater {
            model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

            StyledText {
                required property string modelData

                width: grid.cell
                height: 28
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: Colours.palette.m3primary
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
        }

        Repeater {
            model: root.days

            Item {
                id: day

                required property date modelData
                readonly property bool inMonth: modelData.getMonth() === root.month.getMonth()
                readonly property bool isToday: modelData.toDateString() === root.today.toDateString()
                readonly property string dateIso: Events.iso(modelData)
                readonly property int count: Events.on(dateIso).length
                readonly property bool isPicked: root.agenda && dateIso === root.picked

                width: grid.cell
                height: grid.cellHeight

                StyledRect {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height) - 6
                    height: width
                    radius: width / 2
                    color: day.isToday ? Colours.palette.m3primary : "transparent"
                    border.width: day.isPicked && !day.isToday ? 2 : 0
                    border.color: Colours.palette.m3primary
                }

                // Its events, as up to three dots under the number.
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Math.max(2, (parent.height - Math.min(parent.width, parent.height)) / 2 + 6)
                    spacing: 3

                    Repeater {
                        model: Math.min(3, day.count)

                        Rectangle {
                            width: 4
                            height: 4
                            radius: 2
                            color: day.isToday ? Colours.palette.m3onPrimary : Colours.palette.m3tertiary
                        }
                    }
                }

                TapHandler {
                    enabled: root.agenda
                    onTapped: root.picked = day.dateIso
                }

                StyledText {
                    anchors.centerIn: parent
                    text: day.modelData.getDate()
                    color: day.isToday ? Colours.palette.m3onPrimary : day.inMonth ? Colours.palette.m3onSurface : Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.5)
                    font.pixelSize: 14
                    font.weight: day.isToday ? Font.Bold : Font.Normal
                }
            }
        }
    }

    WheelHandler {
        onWheel: event => root.shift(event.angleDelta.y > 0 ? -1 : 1)
    }

    // ── The picked day's events ──
    Column {
        visible: root.agenda
        anchors.left: grid.right
        anchors.leftMargin: Tokens.spacing.large
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        spacing: Tokens.spacing.normal

        GlossTitle {
            text: Qt.formatDate(new Date(root.picked + "T12:00"), "dddd d MMMM")
            gloss: Xian.chineseDate(new Date(root.picked + "T12:00"))
            size: Tokens.font.value
        }

        Scroller {
            width: parent.width
            height: parent.height - 40 - adder.height - Tokens.spacing.normal * 2
            contentHeight: eventsCol.implicitHeight

            Column {
                id: eventsCol

                width: parent.width
                spacing: 2

                StyledText {
                    visible: root.pickedEvents.length === 0
                    text: "Nothing on this day"
                    color: Colours.palette.m3onSurfaceVariant
                    font.pixelSize: Tokens.font.small
                    topPadding: Tokens.spacing.small
                }

                Repeater {
                    model: root.pickedEvents

                    ListRow {
                        id: ev

                        required property var modelData

                        width: eventsCol.width
                        implicitHeight: 46
                        icon: modelData.external ? "cloud" : modelData.time ? "schedule" : "event"
                        title: modelData.title
                        subtitle: [modelData.time || "all day", modelData.external ?? "", (modelData.remind ?? -1) >= 0 && modelData.time ? `reminds ${modelData.remind} min before` : ""].filter(x => x).join(" · ")

                        IconButton {
                            visible: !ev.modelData.external
                            icon: "delete"
                            size: 30
                            onClicked: Events.remove(ev.modelData.id)

                            Tooltip {
                                text: "Remove"
                            }
                        }
                    }
                }
            }
        }

        // Adding one: a title, an optional time (HH:MM), Enter.
        Row {
            id: adder

            width: parent.width
            spacing: Tokens.spacing.small

            function add(): void {
                Events.add(titleField.text, root.picked, timeField.text, timeField.text.trim() ? Events.remindBefore : -1);
                titleField.text = "";
                timeField.text = "";
            }

            TextField {
                id: titleField

                width: parent.width - 76 - 40 - Tokens.spacing.small * 2
                implicitHeight: 40
                placeholder: "Add an event"
                onAccepted: adder.add()
            }
            TextField {
                id: timeField

                width: 76
                implicitHeight: 40
                placeholder: "HH:MM"
                onAccepted: adder.add()
            }
            IconButton {
                icon: "add"
                size: 40
                filled: true
                fillColour: Colours.palette.m3primary
                inkColour: Colours.palette.m3onPrimary
                onClicked: adder.add()
            }
        }
    }
}
