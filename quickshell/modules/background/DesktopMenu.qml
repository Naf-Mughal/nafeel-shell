pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// The desktop's menu (a right-click on an empty workspace, after Ryoku's):
// quick settings as chips that stay open while toggled (keep awake, night
// light, do not disturb, dark), then the desktop's actions (the wallpaper,
// the bar's edit mode, Settings, the kit, reloading the shell). It floats
// on the wallpaper's own surface, where the click landed.
Floating {
    id: root

    required property string screenName

    readonly property var notifs: Plugins.instance("notifications")

    function openPanel(name: string): void {
        open = false;
        ShellState.anchorTo(name);
        ShellState.pin(name, screenName);
    }

    card.implicitWidth: 300
    card.implicitHeight: body.implicitHeight + 8

    Column {
        id: body

        x: 4
        y: 4
        width: root.card.width - 8
        spacing: 4

        // Quick settings: toggled here, the menu stays.
        Flow {
            width: parent.width
            spacing: Tokens.spacing.small
            padding: Tokens.spacing.small

            Chip {
                text: "Awake"
                icon: "coffee"
                selected: Display.caffeine
                onClicked: Display.toggleCaffeine()
            }
            Chip {
                text: "Night light"
                icon: "nightlight"
                selected: Display.nightLight
                onClicked: Display.toggleNightLight()
            }
            Chip {
                visible: root.notifs !== null
                text: "Quiet"
                icon: "do_not_disturb_on"
                selected: root.notifs?.dnd ?? false
                onClicked: root.notifs.dnd = !root.notifs.dnd
            }
            Chip {
                text: "Dark"
                icon: "dark_mode"
                selected: !Colours.light
                onClicked: Display.toggleDarkMode()
            }
        }

        Hairline {
            width: parent.width
        }

        // The desktop's actions (the goo on the hover).
        Item {
            width: parent.width
            height: rows.height

            ListGoo {
                id: goo

                anchors.fill: rows
                container: rows
                hoverOnly: true
            }

            Column {
                id: rows

                width: parent.width

            Repeater {
                model: [
                    {
                        icon: "wallpaper",
                        text: "Change wallpaper",
                        act: () => root.openPanel("wallpapers")
                    },
                    {
                        icon: "shuffle",
                        text: "Shuffle wallpaper",
                        act: () => {
                            Wallpapers.random();
                            root.open = false;
                        }
                    },
                    {
                        icon: "dashboard_customize",
                        text: "Edit bar",
                        act: () => {
                            root.open = false;
                            ShellState.close();
                            BarLayout.editing = true;
                        }
                    },
                    {
                        icon: "settings",
                        text: "Settings",
                        act: () => root.openPanel("settings")
                    },
                    {
                        icon: "widgets",
                        text: "Kit",
                        act: () => root.openPanel("kit")
                    },
                    {
                        icon: "refresh",
                        text: "Reload shell",
                        act: () => Quickshell.reload(true)
                    }
                ]

                ListRow {
                    required property var modelData

                    width: rows.width
                    implicitHeight: 38
                    goo: goo
                    icon: modelData.icon
                    title: modelData.text
                    onClicked: modelData.act()
                }
            }
            }
        }
    }
}
