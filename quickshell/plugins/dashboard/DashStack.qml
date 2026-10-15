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

    // ── Focus: a timer, do not disturb while it runs ──
    Component {
        id: focusCard

        Row {
            spacing: Tokens.spacing.large

            CircularProgress {
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 76
                strokeWidth: 5
                value: root.timer?.progress ?? 0

                StyledText {
                    anchors.centerIn: parent
                    text: root.timer?.clock ?? "25:00"
                    color: Colours.palette.m3onSurface
                    font.family: Tokens.font.mono
                    font.pixelSize: Tokens.font.body
                    font.weight: Font.DemiBold
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Tokens.spacing.small

                MicroLabel {
                    text: root.timer?.running ? "focusing · quiet" : "focus"
                }
                Row {
                    spacing: Tokens.spacing.small

                    IconButton {
                        icon: root.timer?.running ? "pause" : "play_arrow"
                        size: 34
                        filled: true
                        fillColour: Colours.palette.m3primary
                        inkColour: Colours.palette.m3onPrimary
                        onClicked: root.timer?.running ? root.timer.pause() : root.timer?.start()
                    }
                    IconButton {
                        icon: "restart_alt"
                        size: 34
                        onClicked: root.timer?.reset()
                    }
                }
            }
        }
    }

    // ── System: the busiest processes (read only while this card shows) ──
    Component {
        id: systemCard

        Column {
            id: sys

            property var busiest: []

            spacing: 2

            Process {
                id: ps

                command: ["ps", "-eo", "comm,%cpu", "--sort=-%cpu", "--no-headers"]
                stdout: StdioCollector {
                    onStreamFinished: sys.busiest = text.trim().split("\n").slice(0, 3).map(l => {
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

            MicroLabel {
                text: `system · cpu ${Math.round(SystemStats.cpu * 100)}% · ram ${Math.round(SystemStats.mem * 100)}%`
            }
            Repeater {
                model: sys.busiest

                Row {
                    required property var modelData

                    width: sys.width
                    spacing: Tokens.spacing.small

                    StyledText {
                        width: parent.width - pct.width - Tokens.spacing.small
                        text: parent.modelData[0]
                        color: Colours.palette.m3onSurface
                        font.pixelSize: Tokens.font.small
                        elide: Text.ElideRight
                    }
                    StyledText {
                        id: pct

                        text: parent.modelData[1].toFixed(1) + "%"
                        color: Colours.palette.m3onSurfaceVariant
                        font.family: Tokens.font.mono
                        font.pixelSize: Tokens.font.small
                    }
                }
            }
        }
    }

    // ── Network: the connection, its rates, its last minute ──
    Component {
        id: networkCard

        Item {
            function rate(b: real): string {
                return b > 1048576 ? (b / 1048576).toFixed(1) + " MB/s" : b > 1024 ? Math.round(b / 1024) + " KB/s" : Math.round(b) + " B/s";
            }

            Column {
                id: netText

                spacing: 2

                MicroLabel {
                    text: "network"
                }
                StyledText {
                    text: Network.wired ? (Network.wired.name ?? "Wired") : Network.active?.name ?? "Offline"
                    color: Colours.palette.m3onSurface
                    font.family: Tokens.font.serif
                    font.pixelSize: Tokens.font.value
                }
                StyledText {
                    text: `↓ ${parent.parent.rate(SystemStats.rx)}   ↑ ${parent.parent.rate(SystemStats.tx)}`
                    color: Colours.palette.m3onSurfaceVariant
                    font.family: Tokens.font.mono
                    font.pixelSize: Tokens.font.small
                }
            }

            Sparkline {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: Math.max(60, parent.width - netText.width - Tokens.spacing.large)
                height: parent.height * 0.6
                values: SystemStats.rxHistory
            }
        }
    }

    // ── Agenda: today ──
    Component {
        id: agendaCard

        Row {
            spacing: Tokens.spacing.large

            SystemClock {
                id: day

                precision: SystemClock.Minutes
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    text: Qt.formatDate(day.date, "d")
                    color: Colours.palette.m3primary
                    font.family: Tokens.font.serif
                    font.pixelSize: 40
                }
                MicroLabel {
                    text: Qt.formatDate(day.date, "ddd · MMM")
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                StyledText {
                    text: Xian.chineseDate(day.date)
                    color: Colours.palette.m3onSurface
                    font.family: Tokens.font.cjk
                    font.pixelSize: Tokens.font.row
                }
                MicroLabel {
                    text: {
                        const d = day.date, start = new Date(d.getFullYear(), 0, 1);
                        const week = Math.ceil(((d - start) / 86400000 + start.getDay() + 1) / 7);
                        const end = new Date(d.getFullYear(), 11, 31);
                        return `week ${week} · ${Math.ceil((end - d) / 86400000)} days left`;
                    }
                }
                MicroLabel {
                    text: Xian.shichen(day.date).zh
                }
            }
        }
    }
}
