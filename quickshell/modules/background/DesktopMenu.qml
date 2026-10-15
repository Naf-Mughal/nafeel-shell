pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// The desktop's menu (a right-click on an empty workspace, after Ryoku's):
// its name, quick settings as an even grid of tiles that stay open while
// toggled (keep awake, night light, do not disturb, dark), then the
// everyday actions (the wallpaper, a new note, a screenshot, the bar's edit
// mode, Settings; the kit and reloading the shell are in Settings → Panels).
// It floats on the wallpaper's own surface, where the click landed.
Floating {
    id: root

    required property string screenName

    readonly property var notifs: Plugins.instance("notifications")

    function openPanel(name: string): void {
        open = false;
        ShellState.anchorTo(name);
        ShellState.pin(name, screenName);
    }

    // The screenshot waits for the menu to go (it isn't in the picture).
    Timer {
        id: snipLater

        interval: 250
        onTriggered: Plugins.instance("capture")?.capture?.request("snip", "")
    }

    card.implicitWidth: 300
    card.implicitHeight: body.implicitHeight + 8

    Column {
        id: body

        x: 4
        y: 4
        width: root.card.width - 8
        spacing: 4

        Row {
            spacing: Tokens.spacing.small
            leftPadding: Tokens.spacing.normal
            topPadding: Tokens.spacing.small

            StyledText {
                id: menuTitle

                text: "Desktop"
                font.family: Tokens.font.serif
                font.pixelSize: Tokens.font.body + 2
            }

            StyledText {
                anchors.baseline: menuTitle.baseline
                text: "桌面"
                color: Colours.palette.m3primary
                font.family: Tokens.font.cjk
                font.pixelSize: Tokens.font.small
            }
        }

        // Quick settings, an even grid: toggled here, the menu stays.
        Grid {
            id: quick

            columns: 2
            spacing: Tokens.spacing.small
            padding: Tokens.spacing.small

            readonly property real tileWidth: (body.width - padding * 2 - spacing) / 2

            Tile {
                width: quick.tileWidth
                icon: "coffee"
                label: "Awake"
                checked: Display.caffeine
                onClicked: Display.toggleCaffeine()
            }
            Tile {
                width: quick.tileWidth
                icon: "nightlight"
                label: "Night light"
                checked: Display.nightLight
                onClicked: Display.toggleNightLight()
            }
            Tile {
                width: quick.tileWidth
                visible: root.notifs !== null
                icon: "do_not_disturb_on"
                label: "Quiet"
                checked: root.notifs?.dnd ?? false
                onClicked: root.notifs.dnd = !root.notifs.dnd
            }
            Tile {
                width: quick.tileWidth
                icon: "dark_mode"
                label: "Dark"
                checked: !Colours.light
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
                        icon: "edit_note",
                        text: "New note",
                        act: () => root.openPanel("notes")
                    },
                    {
                        icon: "screenshot_region",
                        text: "Screenshot",
                        act: () => {
                            root.open = false;
                            // Once the menu is off the screen.
                            snipLater.restart();
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
