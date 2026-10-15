pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.components

// A stack of small widgets in one card (the dashboard's corner, after the
// phones' smart stacks): Focus, System, Network, Agenda. Scroll or swipe up
// and down to flip through them; the next one's edge peeks under the card,
// dots on the side say where you are. Only the card in front does any work.
Item {
    id: root

    readonly property var cards: ["focus", "system", "network", "agenda"]
    property int index: 0
    // Which way the last flip went (the new card comes from there).
    property int dir: 1
    readonly property var timer: Plugins.instance("dashboard")?.focus ?? null

    function flip(step: int): void {
        dir = step;
        index = (index + step + cards.length) % cards.length;
    }

    // The next card's edge, under this one.
    StyledRect {
        x: Tokens.spacing.normal
        y: root.height - radius
        width: root.width - Tokens.spacing.normal * 2
        height: radius + 6
        radius: Tokens.rounding.normal
        color: Qt.alpha(Colours.roleFill("paper", "soft", 3), 0.7)
    }

    Surface {
        id: card

        anchors.fill: parent
        level: 2
        clip: true

        // The front card, swapped with a short rise (or fall) and a fade.
        Loader {
            id: front

            property real t: 1

            x: Tokens.spacing.large
            y: Tokens.spacing.normal + (1 - t) * 18 * root.dir
            width: parent.width - Tokens.spacing.large * 2 - 14
            height: parent.height - Tokens.spacing.normal * 2
            opacity: t
            sourceComponent: root.cards[root.index] === "focus" ? focusCard : root.cards[root.index] === "system" ? systemCard : root.cards[root.index] === "network" ? networkCard : agendaCard
            onSourceComponentChanged: if (!Tokens.reduceMotion)
                arrive.restart()

            NumberAnimation {
                id: arrive

                target: front
                property: "t"
                from: 0
                to: 1
                duration: Tokens.anim.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.anim.emphasizedDecel
            }
        }

        // Where you are in the stack.
        Column {
            anchors.right: parent.right
            anchors.rightMargin: Tokens.spacing.normal
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Repeater {
                model: root.cards.length

                Rectangle {
                    required property int index

                    width: 5
                    height: index === root.index ? 14 : 5
                    radius: 2.5
                    color: index === root.index ? Colours.palette.m3primary : Colours.palette.m3outline

                    Behavior on height {
                        Anim {
                            duration: Tokens.anim.fast
                        }
                    }
                }
            }
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            property real acc: 0
            onWheel: event => {
                acc += event.angleDelta.y;
                if (Math.abs(acc) >= 120) {
                    root.flip(acc > 0 ? -1 : 1);
                    acc = 0;
                }
            }
        }

        DragHandler {
            target: null
            xAxis.enabled: false
            onActiveChanged: if (!active && Math.abs(translation.y) > 24)
                root.flip(translation.y < 0 ? 1 : -1)
        }
    }

    // Each card's head: an icon on a badge, the name and its gloss, and a
    // word on the right (its state).
    component CardHead: Item {
        id: head

        property string icon
        property string title
        property string gloss
        property string note

        width: parent?.width ?? 0
        height: 24

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.spacing.small

            Surface {
                width: 22
                height: 22
                role: "secondary"
                shape: "small"

                MaterialIcon {
                    anchors.centerIn: parent
                    text: head.icon
                    fill: 1
                    size: 14
                    color: parent.ink
                }
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: head.title
                color: Colours.palette.m3onSurface
                font.family: Tokens.font.serif
                font.pixelSize: Tokens.font.row
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: head.gloss
                color: Colours.palette.m3primary
                opacity: 0.8
                font.family: Tokens.font.cjk
                font.pixelSize: Tokens.font.small
            }
        }
        MicroLabel {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: head.note
        }
    }

    // ── Focus: a timer, do not disturb while it runs ──
    Component {
        id: focusCard

        Item {
            CardHead {
                id: fh

                icon: "timer"
                title: "Focus"
                gloss: "专注"
                note: root.timer?.running ? "quiet" : `${root.timer?.minutes ?? 25} min`
            }

            Row {
                anchors.top: fh.bottom
                anchors.topMargin: 6
                spacing: Tokens.spacing.large

                CircularProgress {
                    implicitSize: 52
                    strokeWidth: 4
                    gap: 4
                    value: root.timer?.progress ?? 0

                    StyledText {
                        anchors.centerIn: parent
                        text: root.timer?.clock ?? "25:00"
                        color: Colours.palette.m3onSurface
                        font.family: Tokens.font.mono
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.spacing.small

                    // Start / pause: a pill that says it.
                    Surface {
                        implicitWidth: startRow.implicitWidth + Tokens.spacing.large * 2
                        implicitHeight: 34
                        role: "primary"
                        emphasis: "strong"
                        shape: "full"
                        interactive: true
                        onClicked: root.timer?.running ? root.timer.pause() : root.timer?.start()

                        Row {
                            id: startRow

                            anchors.centerIn: parent
                            spacing: 4

                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.timer?.running ? "pause" : "play_arrow"
                                fill: 1
                                size: 18
                                color: parent.parent.ink
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.timer?.running ? "Pause" : (root.timer?.progress ?? 0) > 0 ? "Resume" : "Start"
                                color: parent.parent.ink
                                font.pixelSize: Tokens.font.body
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                    IconButton {
                        icon: "restart_alt"
                        size: 34
                        onClicked: root.timer?.reset()

                        Tooltip {
                            text: "Reset"
                        }
                    }
                }
            }
        }
    }

    // ── System: the load, and what's busiest (read only while shown) ──
    Component {
        id: systemCard

        Item {
            id: sys

            property var busiest: []

            Process {
                id: ps

                command: ["ps", "-eo", "comm,%cpu", "--sort=-%cpu", "--no-headers"]
                stdout: StdioCollector {
                    onStreamFinished: sys.busiest = text.trim().split("\n").slice(0, 1).map(l => {
                        const m = l.trim().match(/^(.*?)\s+([\d.]+)$/);
                        return m ? [m[1], parseFloat(m[2])] : [l, 0];
                    })
                }
            }
            Timer {
                running: sys.visible
                repeat: true
                triggeredOnStart: true
                interval: 3000
                onTriggered: ps.running = true
            }

            CardHead {
                id: sh

                icon: "memory"
                title: "System"
                gloss: "系统"
                note: sys.busiest.length ? `${sys.busiest[0][0]} ${Math.round(sys.busiest[0][1])}%` : ""
            }

            Column {
                anchors.top: sh.bottom
                anchors.topMargin: 10
                width: parent.width
                spacing: 8

                Repeater {
                    model: [["cpu", SystemStats.cpu], ["ram", SystemStats.mem]]

                    Row {
                        required property var modelData

                        width: parent.width
                        spacing: Tokens.spacing.normal

                        MicroLabel {
                            width: 26
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.modelData[0]
                        }
                        LinearProgress {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 26 - 40 - Tokens.spacing.normal * 2
                            value: parent.modelData[1]
                        }
                        StyledText {
                            width: 40
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            text: Math.round(parent.modelData[1] * 100) + "%"
                            color: Colours.palette.m3onSurface
                            font.family: Tokens.font.mono
                            font.pixelSize: Tokens.font.small
                        }
                    }
                }
            }
        }
    }

    // ── Network: the connection, its rates, its last minute ──
    Component {
        id: networkCard

        Item {
            id: net

            function rate(b: real): string {
                return b > 1048576 ? (b / 1048576).toFixed(1) + " MB/s" : b > 1024 ? Math.round(b / 1024) + " KB/s" : Math.round(b) + " B/s";
            }

            CardHead {
                id: nh

                icon: Network.wired ? "lan" : "wifi"
                title: "Network"
                gloss: "网络"
                note: Network.wired ? (Network.wired.name ?? "wired") : Network.active?.name ?? "offline"
            }

            // The last minute, under the rates.
            Sparkline {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 30
                values: SystemStats.rxHistory
                opacity: 0.8
            }

            Row {
                anchors.top: nh.bottom
                anchors.topMargin: 6
                spacing: Tokens.spacing.huge

                Repeater {
                    model: [["arrow_downward", SystemStats.rx], ["arrow_upward", SystemStats.tx]]

                    Row {
                        required property var modelData

                        spacing: 2

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.modelData[0]
                            size: 16
                            color: Colours.palette.m3primary
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: net.rate(parent.modelData[1])
                            color: Colours.palette.m3onSurface
                            font.family: Tokens.font.serif
                            font.pixelSize: Tokens.font.value
                        }
                    }
                }
            }
        }
    }

    // ── Agenda: today, the week around it ──
    Component {
        id: agendaCard

        Row {
            spacing: Tokens.spacing.large

            SystemClock {
                id: day

                precision: SystemClock.Minutes
            }

            // A calendar's page: the month over the day.
            Surface {
                anchors.verticalCenter: parent.verticalCenter
                width: 62
                height: 72
                role: "primary"
                shape: "normal"

                Column {
                    anchors.centerIn: parent

                    MicroLabel {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDate(day.date, "MMM")
                        color: Colours.roleInk("primary", "soft")
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDate(day.date, "d")
                        color: Colours.roleInk("primary", "soft")
                        font.family: Tokens.font.serif
                        font.pixelSize: 32
                    }
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Row {
                    spacing: Tokens.spacing.small

                    StyledText {
                        anchors.baseline: cjk.baseline
                        text: Qt.formatDate(day.date, "dddd")
                        color: Colours.palette.m3onSurface
                        font.family: Tokens.font.serif
                        font.pixelSize: Tokens.font.row
                    }
                    StyledText {
                        id: cjk

                        text: Xian.chineseDate(day.date)
                        color: Colours.palette.m3primary
                        font.family: Tokens.font.cjk
                        font.pixelSize: Tokens.font.small
                    }
                }

                // The week, Monday on: today lit.
                Row {
                    spacing: 4

                    Repeater {
                        model: 7

                        Column {
                            required property int index
                            readonly property bool today: ((day.date.getDay() + 6) % 7) === index

                            spacing: 2

                            MicroLabel {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "MTWTFSS"[parent.index]
                                color: parent.today ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                            }
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.today ? 14 : 6
                                height: 6
                                radius: 3
                                color: parent.today ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3onSurface, 0.2)
                            }
                        }
                    }
                }

                MicroLabel {
                    text: {
                        const d = day.date, start = new Date(d.getFullYear(), 0, 1);
                        const week = Math.ceil(((d - start) / 86400000 + start.getDay() + 1) / 7);
                        const end = new Date(d.getFullYear(), 11, 31);
                        return `week ${week} · ${Math.ceil((end - d) / 86400000)} days left`;
                    }
                }
            }
        }
    }
}
