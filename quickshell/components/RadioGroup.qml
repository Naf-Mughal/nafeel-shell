pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import "keynav.js" as KeyNav

// Radio buttons: a column of choices, each a ring and a label (and a line
// under it); the chosen one's dot is a drop of goo that flows from ring to
// ring when the choice changes (GooIndicator). Arrows move the choice.
//   RadioGroup { model: [{ value, label, sublabel }]; current: …; onSelected: v => … }
Item {
    id: root

    property var model: []
    property var current
    signal selected(var value)

    // Bumped as the rows come (the goo's lookup depends on it).
    property int _items: 0
    readonly property int index: model.findIndex(m => m.value === current)

    implicitWidth: rows.implicitWidth
    implicitHeight: rows.implicitHeight

    property bool focusByKey: false
    activeFocusOnTab: true
    onActiveFocusChanged: {
        if (!activeFocus)
            focusByKey = false;
    }
    Keys.onPressed: event => {
        const k = event.key, n = model.length;
        if ((k === Qt.Key_Down || k === Qt.Key_Right) && index < n - 1)
            selected(model[index + 1].value);
        else if ((k === Qt.Key_Up || k === Qt.Key_Left) && index > 0)
            selected(model[index - 1].value);
        else if (k === Qt.Key_Tab)
            KeyNav.move(root, true);
        else if (k === Qt.Key_Backtab)
            KeyNav.move(root, false);
        else
            return;
        event.accepted = true;
    }

    // The dot: goo flowing between the rings' middles.
    GooIndicator {
        anchors.fill: rows
        z: 1
        selected: root._items >= 0 ? (choices.itemAt(root.index)?.dot ?? null) : null
        fill: Colours.palette.m3primary
        radius: 5
    }

    Column {
        id: rows

        spacing: Tokens.spacing.small

        Repeater {
            id: choices

            model: root.model
            onItemAdded: root._items++
            onItemRemoved: root._items++

            Item {
                id: choice

                required property var modelData
                required property int index
                readonly property bool on: index === root.index
                readonly property Item dot: dotSpot

                implicitWidth: 20 + Tokens.spacing.normal + Math.max(label.implicitWidth, sub.implicitWidth)
                implicitHeight: Math.max(20, texts.implicitHeight)

                StyledRect {
                    id: ring

                    anchors.verticalCenter: texts.verticalCenter
                    anchors.verticalCenterOffset: sub.visible ? -sub.implicitHeight / 2 : 0
                    width: 20
                    height: 20
                    radius: 10
                    color: "transparent"
                    border.width: 2
                    border.color: choice.on ? Colours.palette.m3primary : hover.hovered ? Colours.palette.m3onSurface : Colours.palette.m3outline

                    // Where the dot sits when this one is chosen.
                    Item {
                        id: dotSpot

                        anchors.centerIn: parent
                        width: 10
                        height: 10
                    }

                    // The keyboard's ring.
                    StyledRect {
                        anchors.fill: parent
                        anchors.margins: -4
                        visible: choice.on && root.activeFocus && root.focusByKey
                        radius: width / 2
                        color: "transparent"
                        border.width: 2
                        border.color: Colours.palette.m3primary
                    }
                }

                Column {
                    id: texts

                    anchors.left: ring.right
                    anchors.leftMargin: Tokens.spacing.normal
                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        id: label

                        text: choice.modelData.label ?? ""
                        color: Colours.palette.m3onSurface
                        font.pixelSize: Tokens.font.body
                        font.weight: choice.on ? Font.DemiBold : Font.Normal
                    }
                    StyledText {
                        id: sub

                        visible: text !== ""
                        text: choice.modelData.sublabel ?? ""
                        color: Colours.palette.m3onSurfaceVariant
                        font.pixelSize: Tokens.font.small
                    }
                }

                HoverHandler {
                    id: hover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: root.selected(choice.modelData.value)
                }
            }
        }
    }
}
