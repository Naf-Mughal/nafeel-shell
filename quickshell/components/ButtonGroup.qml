pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// An M3 Expressive connected button group: segments with small inner and
// round outer corners. The selected fill is goo (GooIndicator): it flows to a
// new choice and splits as it goes, and a fainter blob follows the hover.
//   model: [{ value, icon, label }]
Item {
    id: root

    property var model: []
    property var current
    // Tabs: hovering one picks it (after a short rest on it, so crossing the
    // group to somewhere else doesn't flick through every tab). Options that
    // change a setting stay click-only.
    property bool switchOnHover: false
    // Bumped as the Repeater's items come and go (the goo's lookups depend on it).
    property int _items: 0
    signal selected(var value)

    readonly property real spacing: 2
    readonly property real segWidth: (width - spacing * Math.max(0, model.length - 1)) / Math.max(1, model.length)
    readonly property real innerRadius: Math.max(2, Tokens.rounding.small / 2)

    // Segments share the width; without one set, each gets a comfortable
    // 104 px.
    implicitWidth: model.length * 104 + spacing * Math.max(0, model.length - 1)
    implicitHeight: 52
    width: implicitWidth
    height: implicitHeight

    // The segments' paper.
    Repeater {
        model: root.model

        StyledRect {
            required property int index

            x: index * (root.segWidth + root.spacing)
            width: root.segWidth
            height: root.height
            color: Colours.roleFill("paper", "strong", 3)
            topLeftRadius: index === 0 ? Tokens.rounding.morph : root.innerRadius
            bottomLeftRadius: topLeftRadius
            topRightRadius: index === root.model.length - 1 ? Tokens.rounding.morph : root.innerRadius
            bottomRightRadius: topRightRadius
        }
    }

    // Only the pointer's own moves switch: a switch can resize the panel
    // and slide the tabs under a still pointer onto the next one, which
    // then switched back, and so on (ping-pong between two tabs).
    HoverHandler {
        id: pointer
    }
    property point switchedAt: Qt.point(-999, -999)
    property double switchedTime: 0

    Timer {
        id: dwell

        interval: 90
        onTriggered: {
            const s = goo.hovered;
            if (!s || s.modelData.value === root.current)
                return;
            const p = pointer.point.scenePosition;
            const moved = Math.hypot(p.x - root.switchedAt.x, p.y - root.switchedAt.y) > 6;
            if (!moved || Date.now() - root.switchedTime < 250)
                return;
            root.switchedAt = p;
            root.switchedTime = Date.now();
            root.selected(s.modelData.value);
        }
    }

    GooIndicator {
        id: goo

        onHoveredChanged: if (root.switchOnHover)
            dwell.restart()

        anchors.fill: parent
        // Read again as the items arrive (itemAt and count say nothing then).
        selected: root._items >= 0 ? segs.itemAt(root.model.findIndex(m => m.value === root.current)) : null
        hovered: {
            void root._items;
            for (let i = 0; i < segs.count; i++) {
                const s = segs.itemAt(i);
                if (s?.hovered)
                    return s;
            }
            return null;
        }
        fill: Colours.roleFill("secondary", "strong", 0)
        radius: Tokens.rounding.morph
    }

    Repeater {
        id: segs

        model: root.model
        onItemAdded: root._items++
        onItemRemoved: root._items++

        Surface {
            id: seg

            required property var modelData
            required property int index
            readonly property bool on: modelData.value === root.current
            // Under the fill right now (the ink turns with the goo).
            readonly property bool inked: goo.covers(seg)

            emphasis: "ghost"
            interactive: true
            hoverLayer: false
            pressDepth: 0.95
            morph: false
            radius: Tokens.rounding.morph
            x: index * (root.segWidth + root.spacing)
            width: root.segWidth
            height: root.height
            baseInk: inked ? Colours.roleInk("secondary", "strong") : Colours.roleInk("paper", "soft")
            baseSubInk: inked ? baseInk : Colours.roleSubInk("paper", "soft")
            onClicked: root.selected(seg.modelData.value)

            Column {
                anchors.centerIn: parent
                spacing: 0

                MaterialIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: seg.modelData.icon
                    fill: seg.inked ? 1 : 0
                    color: seg.ink
                    size: 18
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: seg.modelData.label
                    color: seg.inked ? seg.ink : seg.subInk
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }
        }
    }
}
