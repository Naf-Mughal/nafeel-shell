pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.components

// Session: clock, date and uptime on top, then the actions as big expressive
// tiles. Actions go through Noctalia (`session <action>`), so the Cave Abode
// lock and Graceful Power commands apply. Log out, reboot and shut down ask
// for a second press within 4 s.
Panel {
    id: root

    property string armed: ""
    property string uptime: ""


    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    FileView {
        id: uptimeFile

        path: "/proc/uptime"
        onLoaded: {
            const s = parseFloat(text());
            const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
            root.uptime = `Up ${d > 0 ? d + " d " : ""}${h > 0 ? h + " h " : ""}${m} min`;
        }
    }

    Timer {
        id: disarm

        interval: 4000
        onTriggered: root.armed = ""
    }

    Row {
        width: parent.width
        spacing: Tokens.spacing.normal

        StyledText {
            text: Time.time(clock.date)
            font.family: Tokens.font.serif
            font.pixelSize: 34
            font.weight: Font.DemiBold
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                text: Qt.formatDate(clock.date, "dddd, MMMM d")
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            StyledText {
                text: root.uptime
                color: Colours.palette.m3onSurfaceVariant
                font.pixelSize: 12
            }

            StyledText {
                text: `${Xian.shichen(clock.date).zh} · ${Xian.chineseDate(clock.date)}`
                color: Colours.palette.m3primary
                font.family: Tokens.font.cjk
                font.pixelSize: Tokens.font.small
            }
        }
    }

    Flow {
        width: parent.width
        spacing: Tokens.spacing.small

        Repeater {
            model: [
                {
                    action: "lock",
                    icon: "lock",
                    label: "Lock",
                    confirm: false
                },
                {
                    action: "suspend",
                    icon: "bedtime",
                    label: "Suspend",
                    confirm: false
                },
                {
                    action: "logout",
                    icon: "logout",
                    label: "Log out",
                    confirm: true
                },
                {
                    action: "reboot",
                    icon: "restart_alt",
                    label: "Restart",
                    confirm: true
                },
                {
                    action: "shutdown",
                    icon: "power_settings_new",
                    label: "Shut down",
                    confirm: true
                }
            ]

            Tile {
                required property var modelData
                required property int index

                // The last tile (shut down) spans both columns.
                width: index === 4 ? root.width : (root.width - Tokens.spacing.small) / 2
                icon: modelData.icon
                label: root.armed === modelData.action ? "Sure?" : modelData.label
                sublabel: root.armed === modelData.action ? "Press again" : ""
                checked: root.armed === modelData.action
                onClicked: {
                    if (modelData.confirm && root.armed !== modelData.action) {
                        root.armed = modelData.action;
                        disarm.restart();
                        return;
                    }
                    ShellState.close();
                    Session.run(modelData.action);
                }
            }
        }
    }
}
