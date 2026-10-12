pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.config

// System tray icons: click activates, right-click opens the app's menu.
Column {
    id: root

    property ShellScreen shellScreen

    spacing: Tokens.spacing.small

    Repeater {
        model: SystemTray.items

        Item {
            id: entry

            required property SystemTrayItem modelData

            width: parent.width
            height: 26

            IconImage {
                anchors.centerIn: parent
                implicitSize: 18
                source: {
                    // Some apps hand a path query in the icon name.
                    const icon = entry.modelData.icon;
                    return icon.includes("?path=") ? `file://${icon.split("?path=")[1]}/${icon.split("?")[0].split("/").pop()}` : icon;
                }
                scale: tap.pressed ? 0.85 : hover.hovered ? 1.12 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: Tokens.anim.fast
                    }
                }
            }

            HoverHandler {
                id: hover
            }

            QsMenuAnchor {
                id: menu

                menu: entry.modelData.menu
                anchor.item: entry
                anchor.edges: Edges.Right
                anchor.gravity: Edges.Right
            }

            TapHandler {
                id: tap

                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onTapped: (point, button) => {
                    if (button === Qt.RightButton || entry.modelData.onlyMenu) {
                        if (entry.modelData.hasMenu)
                            menu.open();
                    } else {
                        entry.modelData.activate();
                    }
                }
            }
        }
    }
}
