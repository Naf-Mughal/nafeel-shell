pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.components

// A stack of small widgets in one card (the dashboard's corner, after the
// phones' smart stacks): Focus, System, Network, Agenda. Scroll or swipe up
// and down to flip through them; dots on the side say where you are (it
// stays inside its card: an edge peeking under it read as spilling out). Only the card in front does any work.
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
            y: Tokens.spacing.large + (1 - t) * 18 * root.dir
            width: parent.width - Tokens.spacing.large * 2 - 12
            height: parent.height - Tokens.spacing.large * 2
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

    // A card's caption: small, tracked, under or beside its one big value.
    component Caption: MicroLabel {}

    // ── Focus: the time large, play and reset, the elapsed as a line ──
    Component {
        id: focusCard

        Item {
            Column {
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    text: root.timer?.clock ?? "25:00"
                    color: Colours.palette.m3onSurface
                    font.family: Tokens.font.serif
                    font.pixelSize: 40
                }
                Caption {
                    text: root.timer?.running ? "focusing · quiet" : `focus · ${root.timer?.minutes ?? 25} min`
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Tokens.spacing.small

                IconButton {
                    icon: root.timer?.running ? "pause" : "play_arrow"
                    size: 38
                    filled: true
                    fillColour: Colours.palette.m3primary
                    inkColour: Colours.palette.m3onPrimary
                    onClicked: root.timer?.running ? root.timer.pause() : root.timer?.start()

                    Tooltip {
                        text: root.timer?.running ? "Pause" : "Start focus"
                    }
                }
                IconButton {
                    icon: "restart_alt"
                    size: 38
                    onClicked: root.timer?.reset()

                    Tooltip {
                        text: "Reset"
                    }
                }
            }

            // The elapsed, along the bottom.
            LinearProgress {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                value: root.timer?.progress ?? 0
                visible: (root.timer?.progress ?? 0) > 0
            }
        }
    }

    // ── System: CPU and RAM, large, side by side ──
    Component {
        id: systemCard

        Item {
            id: sys

            property string busiest: ""

            Process {
                id: ps

                command: ["ps", "-eo", "comm", "--sort=-%cpu", "--no-headers"]
                stdout: StdioCollector {
                    onStreamFinished: sys.busiest = text.trim().split("\n")[0] ?? ""
                }
            }
            Timer {
                running: sys.visible
                repeat: true
                triggeredOnStart: true
                interval: 3000
                onTriggered: ps.running = true
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: Tokens.spacing.large

                Repeater {
                    model: [["cpu", SystemStats.cpu], ["ram", SystemStats.mem]]

                    Column {
                        required property var modelData
                        required property int index

                        width: (parent.width - Tokens.spacing.large) / 2
                        spacing: 4

                        StyledText {
                            text: Math.round(parent.modelData[1] * 100) + "%"
                            color: Colours.palette.m3onSurface
                            font.family: Tokens.font.serif
                            font.pixelSize: 34
                        }
                        LinearProgress {
                            width: parent.width
                            value: parent.modelData[1]
                        }
                        Caption {
                            width: parent.width
                            elide: Text.ElideRight
                            text: parent.index === 0 && sys.busiest ? `cpu · ${sys.busiest}` : parent.modelData[0]
                        }
                    }
                }
            }
        }
    }

    // ── Network: down large, over the last minute ──
    Component {
        id: networkCard

        Item {
            id: net

            function rate(b: real): string {
                return b > 1048576 ? (b / 1048576).toFixed(1) + " MB/s" : b > 1024 ? Math.round(b / 1024) + " KB/s" : Math.round(b) + " B/s";
            }

            // The last minute, faint, across the card.
            Sparkline {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.height * 0.55
                values: SystemStats.rxHistory
                opacity: 0.45
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter

                Row {
                    spacing: 2

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "arrow_downward"
                        size: 22
                        color: Colours.palette.m3primary
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: net.rate(SystemStats.rx)
                        color: Colours.palette.m3onSurface
                        font.family: Tokens.font.serif
                        font.pixelSize: 32
                    }
                }
                Caption {
                    text: `${Network.wired ? (Network.wired.name ?? "wired") : Network.active?.name ?? "offline"} · up ${net.rate(SystemStats.tx)}`
                }
            }
        }
    }

    // ── Agenda: today, large ──
    Component {
        id: agendaCard

        Row {
            spacing: Tokens.spacing.large

            SystemClock {
                id: day

                precision: SystemClock.Minutes
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDate(day.date, "d")
                color: Colours.palette.m3primary
                font.family: Tokens.font.serif
                font.pixelSize: 52
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                StyledText {
                    text: Qt.formatDate(day.date, "dddd")
                    color: Colours.palette.m3onSurface
                    font.family: Tokens.font.serif
                    font.pixelSize: Tokens.font.value
                }
                StyledText {
                    text: `${Qt.formatDate(day.date, "MMMM")} · ${Xian.chineseDate(day.date)}`
                    color: Colours.palette.m3onSurfaceVariant
                    font.pixelSize: Tokens.font.small
                }
                Caption {
                    text: {
                        const d = day.date, start = new Date(d.getFullYear(), 0, 1);
                        const week = Math.ceil(((d - start) / 86400000 + start.getDay() + 1) / 7);
                        return `week ${week} · ${Math.ceil((new Date(d.getFullYear(), 11, 31) - d) / 86400000)} days left`;
                    }
                }
            }
        }
    }
}
