pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import M3Shapes
import qs.config
import qs.services
import qs.components

// Performance (Caelestia's layout, on the shell's parts): the processor and
// the graphics as hero cards (load ring round the icon, name, temperature on
// a bar, usage in a shape that grows spikier as it climbs), then storage,
// network and memory, and the battery as a tank down the side.
RowLayout {
    id: root

    implicitHeight: 330
    spacing: Tokens.spacing.normal

    Component.onCompleted: SystemStats.watchers++
    Component.onDestruction: SystemStats.watchers--

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Tokens.spacing.normal

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.normal

            PerfHeroCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 124
                icon: "memory"
                label: "CPU"
                subLabel: SystemStats.cpuName
                usage: SystemStats.cpu
                temperature: SystemStats.temp
                role: "primary"
            }

            PerfHeroCard {
                visible: SystemStats.gpu >= 0
                Layout.fillWidth: true
                Layout.preferredHeight: 124
                icon: "desktop_windows"
                label: "GPU"
                subLabel: SystemStats.gpuName ? `Radeon ${SystemStats.gpuName}` : "Graphics"
                usage: SystemStats.gpu
                temperature: SystemStats.gpuTemp
                role: "secondary"
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Tokens.spacing.normal

            // ── Storage: one gauge per physical drive (as the memory card) ──
            Surface {
                id: storage

                Layout.fillHeight: true
                Layout.preferredWidth: Math.max(1, SystemStats.disks.length) * 132 + Tokens.spacing.large * 2
                level: 2

                Column {
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.small

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: "hard_drive"
                            fill: 1
                            size: 22
                            color: Colours.roleInk("secondary", "ghost")
                        }

                        StyledText {
                            text: "Storage"
                            color: storage.ink
                            font.pixelSize: Tokens.font.title
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Tokens.spacing.normal

                        Repeater {
                            model: SystemStats.disks

                            Column {
                                id: drive

                                required property var modelData
                                readonly property real used: modelData.total > 0 ? modelData.used / modelData.total : 0

                                width: 122
                                spacing: 2

                                CircularProgress {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    implicitSize: 96
                                    startAngle: -225
                                    sweepAngle: 270
                                    strokeWidth: 8
                                    value: drive.used
                                    fg: Colours.roleInk("secondary", "ghost")

                                    Column {
                                        anchors.centerIn: parent

                                        StyledText {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: `${Math.round(drive.used * 100)}%`
                                            color: Colours.roleInk("secondary", "ghost")
                                            font.pixelSize: 22
                                            font.weight: Font.DemiBold
                                        }

                                        StyledText {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: "Used"
                                            color: storage.subInk
                                            font.pixelSize: Tokens.font.small
                                        }
                                    }
                                }

                                StyledText {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    // The maker and line ("SAMSUNG MZALQ…" -> "SAMSUNG", "WD PC SN740…" -> "WD SN740").
                                    text: drive.modelData.model.replace(/\b(PC|-\S*)\b/g, "").split(/\s+/).filter((w, i) => w && (i === 0 || w.length <= 8)).slice(0, 2).join(" ") || drive.modelData.name
                                    color: storage.ink
                                    font.pixelSize: Tokens.font.small
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: `${SystemStats.bytes(drive.modelData.used)} / ${SystemStats.bytes(drive.modelData.total)}`
                                    color: storage.subInk
                                    font.pixelSize: Tokens.font.small
                                }
                            }
                        }
                    }
                }
            }

            // ── Network ──
            Surface {
                id: net

                Layout.fillWidth: true
                Layout.fillHeight: true
                level: 2
                shape: "large"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.spacing.normal
                    spacing: 2

                    Row {
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: "swap_vert"
                            size: 22
                            color: Colours.roleInk("primary", "ghost")
                        }

                        StyledText {
                            text: "Network"
                            color: net.ink
                            font.pixelSize: Tokens.font.title
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Sparkline {
                            anchors.fill: parent
                            values: SystemStats.txHistory
                            max: Math.max(1024, ...SystemStats.rxHistory, ...SystemStats.txHistory)
                            colour: Colours.roleInk("secondary", "ghost")
                        }

                        Sparkline {
                            anchors.fill: parent
                            values: SystemStats.rxHistory
                            max: Math.max(1024, ...SystemStats.rxHistory, ...SystemStats.txHistory)
                            colour: Colours.roleInk("tertiary", "ghost")
                        }

                        MicroLabel {
                            anchors.centerIn: parent
                            visible: SystemStats.rxHistory.length < 2
                            text: "collecting data…"
                        }
                    }

                    PerfReading {
                        icon: "download"
                        label: "Download"
                        value: `${SystemStats.bytes(SystemStats.rx)}/s`
                        role: "tertiary"
                    }

                    PerfReading {
                        icon: "upload"
                        label: "Upload"
                        value: `${SystemStats.bytes(SystemStats.tx)}/s`
                        role: "secondary"
                    }

                    PerfReading {
                        icon: "history"
                        label: "Total"
                        value: `↓${SystemStats.bytes(SystemStats.rxTotal)} ↑${SystemStats.bytes(SystemStats.txTotal)}`
                        role: "paper"
                    }
                }
            }

            // ── Memory ──
            Surface {
                id: mem

                Layout.fillHeight: true
                Layout.preferredWidth: 180
                level: 2

                Column {
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.small

                    Row {
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: "memory_alt"
                            fill: 1
                            size: 22
                            color: Colours.roleInk("tertiary", "ghost")
                        }

                        StyledText {
                            text: "Memory"
                            color: mem.ink
                            font.pixelSize: Tokens.font.title
                        }
                    }

                    CircularProgress {
                        anchors.horizontalCenter: parent.horizontalCenter
                        implicitSize: 104
                        startAngle: -225
                        sweepAngle: 270
                        strokeWidth: 8
                        value: SystemStats.mem
                        fg: Colours.roleInk("tertiary", "ghost")

                        Column {
                            anchors.centerIn: parent

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: `${Math.round(SystemStats.mem * 100)}%`
                                color: Colours.roleInk("tertiary", "ghost")
                                font.pixelSize: 26
                                font.weight: Font.DemiBold
                            }

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Used"
                                color: mem.subInk
                                font.pixelSize: Tokens.font.small
                            }
                        }
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: `${SystemStats.bytes(SystemStats.memUsed)} / ${SystemStats.bytes(SystemStats.memTotal)}`
                        color: mem.ink
                        font.pixelSize: Tokens.font.row
                    }
                }
            }
        }
    }

    // ── The battery, a tank that fills ──
    Item {
        visible: Power.hasBattery
        Layout.preferredWidth: 128
        Layout.fillHeight: true

        Surface {
            id: tank

            anchors.fill: parent
            role: "secondary"
            emphasis: "soft"
            shape: "large"
            clip: true

            PerfTankContents {
                anchors.fill: parent
                anchors.margins: Tokens.spacing.normal
                accent: Colours.roleInk("primary", "ghost")
                ink: tank.ink
                subInk: tank.subInk
            }

            // The charge, rising from the bottom, with the same words over it
            // in the fill's own ink.
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.height * Power.level
                radius: Tokens.rounding.small
                color: Colours.roleFill(Power.low ? "error" : "secondary", "strong", 0)
                clip: true

                Behavior on height {
                    Anim {}
                }

                PerfTankContents {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Tokens.spacing.normal
                    height: tank.height - Tokens.spacing.normal * 2
                    accent: Colours.roleFill("primary", "soft", 0)
                    ink: Colours.roleInk(Power.low ? "error" : "secondary", "strong")
                    subInk: Qt.alpha(Colours.roleInk(Power.low ? "error" : "secondary", "strong"), 0.75)
                }
            }
        }
    }


}
