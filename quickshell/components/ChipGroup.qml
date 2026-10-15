pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// A row of chips to pick one from: each chip on its paper, the selected
// fill as goo (GooIndicator) that flows to a new choice, a fainter blob
// following the hover. One row (put it in a Strip to scroll a long one).
//   model: [{ value, label, icon }]
Item {
    id: root

    property var model: []
    property var current
    // Bumped as the Repeater's items come and go (the goo's lookups depend on it).
    property int _items: 0
    signal selected(var value)

    implicitWidth: flow.implicitWidth
    implicitHeight: flow.implicitHeight

    // The chips' paper, under the goo.
    Repeater {
        model: chips.count

        StyledRect {
            required property int index
            readonly property Item chip: chips.itemAt(index)

            x: chip?.x ?? 0
            y: chip?.y ?? 0
            width: chip?.width ?? 0
            height: chip?.height ?? 0
            radius: Tokens.rounding.morph
            color: Colours.roleFill("paper", "soft", 3)
        }
    }

    GooIndicator {
        id: goo

        anchors.fill: flow
        // Read again as the items arrive (itemAt and count say nothing then).
        selected: root._items >= 0 ? chips.itemAt(root.model.findIndex(m => m.value === root.current)) : null
        hovered: chipHover.current
        fill: Colours.roleFill("secondary", "soft", 0)
        radius: Tokens.rounding.morph
    }

    // The hover with dead zones, the pointer's own moves only.
    HoverTracker {
        id: chipHover

        items: {
            void root._items;
            const out = [];
            for (let i = 0; i < chips.count; i++)
                out.push(chips.itemAt(i));
            return out;
        }
    }

    Row {
        id: flow

        spacing: Tokens.spacing.small

        Repeater {
            id: chips

            model: root.model
            onItemAdded: root._items++
            onItemRemoved: root._items++

            Chip {
                id: chip

                required property var modelData

                text: modelData.label
                icon: modelData.icon ?? ""
                // Under the fill right now (the ink turns with the goo).
                selected: goo.covers(chip)
                fill: "transparent"
                inkFill: false
                hoverLayer: false
                baseInk: selected ? Colours.roleInk("secondary", "soft") : Colours.roleInk("paper", "soft")
                baseSubInk: selected ? baseInk : Colours.roleSubInk("paper", "soft")
                onClicked: root.selected(modelData.value)
            }
        }
    }
}
