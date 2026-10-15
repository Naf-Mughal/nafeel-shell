pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// A menu (right-click, an overflow ⋯, a Select's list): rows unfolding like
// ink from where it opened (Floating), the goo following the hover or the
// keys (ListGoo), resting on `current` when there is one. Up / Down move,
// Enter picks, Esc closes.
//   Menu { id: m; from: button; model: [{ value, text, icon, danger }]; onPicked: v => … }
//   … m.show()   (or m.popup(item, point) for a right-click)
Floating {
    id: root

    property var model: []
    // The row it starts on and rests the goo on (a Select's value).
    property var current
    property real minWidth: 180
    signal picked(var value)

    property int keyIndex: -1

    function popup(item: Item, point: point): void {
        from = item;
        at = point;
        show();
    }

    onOpenChanged: if (open)
        keyIndex = model.findIndex(m => m.value === current)

    card.implicitWidth: Math.max(minWidth, rows.implicitWidth) + 8
    card.implicitHeight: rows.implicitHeight + 8
    onKeyPressed: event => {
        const n = model.length;
        if (event.key === Qt.Key_Down)
            keyIndex = (keyIndex + 1) % n;
        else if (event.key === Qt.Key_Up)
            keyIndex = (keyIndex - 1 + n) % n;
        else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && keyIndex >= 0)
            choose(model[keyIndex].value);
        else
            return;
        event.accepted = true;
    }

    function choose(value: var): void {
        picked(value);
        open = false;
    }

    ListGoo {
        id: goo

        anchors.fill: rows
        container: rows
    }

    Column {
        id: rows

        x: 4
        y: 4
        width: root.card.width - 8

        Repeater {
            model: root.model

            ListRow {
                id: row

                required property var modelData
                required property int index

                width: rows.width
                implicitHeight: 38
                goo: goo
                // The goo rests on the keys' row, or the current value.
                picked: root.keyIndex >= 0 ? index === root.keyIndex : modelData.value === root.current
                icon: modelData.icon ?? ""
                title: modelData.text ?? ""
                baseInk: inked ? Colours.roleInk("secondary", "soft") : modelData.danger ? Colours.palette.m3error : Colours.roleInk("paper", "soft")
                onClicked: root.choose(modelData.value)
                onHoveredChanged: if (hovered)
                    root.keyIndex = -1
            }
        }
    }
}
