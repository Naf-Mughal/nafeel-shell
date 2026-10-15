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
        // Read again once the items exist (itemAt says nothing when they arrive).
        selected: chips.count > 0 ? chips.itemAt(root.model.findIndex(m => m.value === root.current)) : null
        hovered: {
            for (let i = 0; i < chips.count; i++) {
                const c = chips.itemAt(i);
                if (c?.hovered)
                    return c;
            }
            return null;
        }
        fill: Colours.roleFill("secondary", "soft", 0)
        hoverFill: Qt.alpha(Colours.palette.m3onSurface, 0.1)
        radius: Tokens.rounding.morph
    }

    Row {
        id: flow

        spacing: Tokens.spacing.small

        Repeater {
            id: chips

            model: root.model

            Chip {
                id: chip

                required property var modelData

                text: modelData.label
                icon: modelData.icon ?? ""
                // Under the fill right now (the ink turns with the goo).
                selected: goo.covers(chip)
                fill: "transparent"
                hoverLayer: false
                baseInk: selected ? Colours.roleInk("secondary", "soft") : Colours.roleInk("paper", "soft")
                baseSubInk: selected ? baseInk : Colours.roleSubInk("paper", "soft")
                onClicked: root.selected(modelData.value)
            }
        }
    }
}
