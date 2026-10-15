pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.components

// The command center's tabs: the goo rests on the open one and follows the
// hover (ListGoo); a tab rested on a moment opens (tabs switch on hover).
Item {
    id: root

    required property var tabs // [{ id, icon, label }]

    // A tab rested on opens (crossing the list doesn't flick through them);
    // only the pointer's own moves switch (a layout shift under a still
    // pointer doesn't).
    HoverHandler {
        id: pointer
    }
    property point switchedAt: Qt.point(-999, -999)
    property double switchedTime: 0

    Timer {
        id: dwell

        interval: 90
        onTriggered: {
            const t = goo.hovered;
            if (!t || ShellState.ccTab === t.modelData.id)
                return;
            const p = pointer.point.scenePosition;
            if (Math.hypot(p.x - root.switchedAt.x, p.y - root.switchedAt.y) <= 6 || Date.now() - root.switchedTime < 250)
                return;
            root.switchedAt = p;
            root.switchedTime = Date.now();
            ShellState.ccTab = t.modelData.id;
        }
    }

    ListGoo {
        id: goo

        anchors.fill: column
        container: column
        radius: Tokens.rounding.small
        onHoveredChanged: dwell.restart()
    }

    Column {
        id: column

        width: parent.width
        spacing: 2

        Repeater {
            model: root.tabs

            Surface {
                id: tab

                required property var modelData
                readonly property bool current: ShellState.ccTab === modelData.id
                // A goo row: the goo rests on the open tab.
                property Item goo: goo
                readonly property bool picked: current
                readonly property bool inked: goo.covers(tab)

                width: column.width
                height: 40
                emphasis: "ghost"
                interactive: true
                hoverLayer: false
                pressDepth: 1
                morph: false
                shape: "small"
                baseInk: inked ? Colours.roleInk("secondary", "soft") : Colours.roleInk("paper", "soft")
                baseSubInk: inked ? Colours.roleSubInk("secondary", "soft") : Colours.roleSubInk("paper", "soft")
                onClicked: ShellState.ccTab = modelData.id

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Tokens.spacing.normal
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.spacing.normal

                    MaterialIcon {
                        text: tab.modelData.icon
                        fill: tab.inked ? 1 : 0
                        color: tab.inked ? tab.ink : tab.subInk
                        size: 20
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: tab.modelData.label
                        color: tab.ink
                        font.pixelSize: 13
                        font.weight: tab.current ? Font.DemiBold : Font.Normal
                    }
                }

                // The tab's Chinese gloss, on the right.
                StyledText {
                    anchors.right: parent.right
                    anchors.rightMargin: Tokens.spacing.normal
                    anchors.verticalCenter: parent.verticalCenter
                    text: tab.modelData.gloss ?? Xian.gloss[tab.modelData.id] ?? ""
                    color: tab.inked ? tab.ink : Colours.palette.m3outline
                    opacity: tab.inked ? 0.9 : 0.7
                    font.family: Tokens.font.cjk
                    font.pixelSize: Tokens.font.row
                    font.letterSpacing: 1
                }
            }
        }
    }
}
