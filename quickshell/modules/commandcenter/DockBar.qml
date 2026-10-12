pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.components

// The dock: its apps split evenly either side of the command center's icon,
// pinned ones first, then other running ones. Resting on an
// app previews its windows above it (DockPreview); resting on the middle
// icon opens the
// command center, a click opens or closes it. Nothing else on the dock
// opens anything by hover.
Row {
    id: root

    property bool expanded: false // the command center is open above it
    property string screenName: ""
    readonly property var items: Dock.items
    readonly property int half: Math.ceil(items.length / 2)

    spacing: Tokens.spacing.small

    Repeater {
        model: root.items.slice(0, root.half)

        DockItem {
            expanded: root.expanded
            screenName: root.screenName
        }
    }

    // The command center's icon.
    Item {
        id: centre

        width: 52
        height: 64

        // A symbol like the apps' (AppIcon's), in the primary colour.
        MaterialIcon {
            anchors.centerIn: parent
            text: "apps"
            size: Dock.settings.v["dock.iconSize"] - 4
            fill: 1
            color: Colours.palette.m3primary
            opacity: root.expanded || centreHover.hovered ? 1 : 0.86

            Behavior on opacity {
                Anim {
                    duration: Tokens.anim.fast
                }
            }
        }

        TapHandler {
            onTapped: {
                rest.stop();
                if (root.expanded)
                    ShellState.close();
                else
                    ShellState.pin("command", root.screenName);
            }
        }

        HoverHandler {
            id: centreHover

            cursorShape: Qt.PointingHandCursor
        }

        Timer {
            id: rest

            running: centreHover.hovered && !root.expanded
            interval: Dock.settings.v["dock.centerDelay"]
            onTriggered: {
                ShellState.dockPreview = "";
                ShellState.preview("command", root.screenName);
            }
        }
    }

    Repeater {
        model: root.items.slice(root.half)

        DockItem {
            expanded: root.expanded
            screenName: root.screenName
        }
    }
}
