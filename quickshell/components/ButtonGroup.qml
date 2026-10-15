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

    GooIndicator {
        anchors.fill: parent
        selected: segs.itemAt(root.model.findIndex(m => m.value === root.current))
        hovered: {
            for (let i = 0; i < segs.count; i++) {
                const s = segs.itemAt(i);
                if (s?.hovered)
                    return s;
            }
            return null;
        }
        fill: Colours.roleFill("secondary", "strong", 0)
        hoverFill: Qt.alpha(Colours.palette.m3onSurface, 0.1)
        radius: Tokens.rounding.morph
    }

    Repeater {
        id: segs

        model: root.model

        Surface {
            id: seg

            required property var modelData
            required property int index
            readonly property bool on: modelData.value === root.current

            emphasis: "ghost"
            interactive: true
            hoverLayer: false
            pressDepth: 0.95
            morph: false
            radius: Tokens.rounding.morph
            x: index * (root.segWidth + root.spacing)
            width: root.segWidth
            height: root.height
            baseInk: on ? Colours.roleInk("secondary", "strong") : Colours.roleInk("paper", "soft")
            baseSubInk: on ? baseInk : Colours.roleSubInk("paper", "soft")
            onClicked: root.selected(seg.modelData.value)

            Column {
                anchors.centerIn: parent
                spacing: 0

                MaterialIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: seg.modelData.icon
                    fill: seg.on ? 1 : 0
                    color: seg.ink
                    size: 18
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: seg.modelData.label
                    color: seg.on ? seg.ink : seg.subInk
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }
        }
    }
}
