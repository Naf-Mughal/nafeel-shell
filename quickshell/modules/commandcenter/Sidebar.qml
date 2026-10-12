pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.components

// The command center's tabs, with an active pill that springs between them.
Item {
    id: root

    required property var tabs // [{ id, icon, label }]

    Column {
        id: column

        width: parent.width
        spacing: 2

        Repeater {
            model: root.tabs

            Item {
                id: tab

                required property var modelData
                readonly property bool current: ShellState.ccTab === modelData.id

                width: column.width
                height: 40

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Tokens.spacing.normal
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.spacing.normal
                    z: 1

                    MaterialIcon {
                        text: tab.modelData.icon
                        fill: tab.current ? 1 : 0
                        color: tab.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                        size: 20
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: tab.modelData.label
                        color: tab.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                        font.pixelSize: 13
                        font.weight: tab.current ? Font.DemiBold : Font.Normal
                    }
                }

                StyledRect {
                    anchors.fill: parent
                    radius: Tokens.rounding.small

                    StateLayer {
                        hovered: hover.hovered && !tab.current
                        pressed: tabTap.pressed
                        ink: Colours.palette.m3onSurface
                    }
                }

                // The tab's Chinese gloss, on the right.
                StyledText {
                    anchors.right: parent.right
                    anchors.rightMargin: Tokens.spacing.normal
                    anchors.verticalCenter: parent.verticalCenter
                    z: 1
                    text: tab.modelData.gloss ?? Xian.gloss[tab.modelData.id] ?? ""
                    color: tab.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3outline
                    opacity: tab.current ? 0.9 : 0.7
                    font.family: Tokens.font.cjk
                    font.pixelSize: Tokens.font.row
                    font.letterSpacing: 1
                }

                HoverHandler {
                    id: hover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    id: tabTap

                    onTapped: ShellState.ccTab = tab.modelData.id
                }
            }
        }
    }

    StyledRect {
        id: pill

        readonly property int index: root.tabs.findIndex(t => t.id === ShellState.ccTab)

        z: -1
        width: parent.width
        height: 40
        y: Math.max(0, index) * 42
        radius: Tokens.rounding.small
        color: Colours.palette.m3secondaryContainer
        opacity: index >= 0 ? 1 : 0

        Behavior on y {
            SpringAnimation {
                spring: Tokens.springK(4)
                damping: Tokens.dampK(0.32)
                epsilon: 0.25
            }
        }
    }
}
