pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// An M3 Expressive connected button group (Surfaces): segments with small inner and
// round outer corners; the selected one fills and rounds fully.
//   model: [{ value, icon, label }]
Row {
    id: root

    property var model: []
    property var current
    signal selected(var value)

    spacing: 2
    // Segments share the width; without one set, each gets a comfortable
    // 104 px (a Row takes no width from children sized from it).
    width: model.length * 104 + spacing * Math.max(0, model.length - 1)

    Repeater {
        model: root.model

        Surface {
            id: seg

            required property var modelData
            required property int index
            readonly property bool on: modelData.value === root.current
            readonly property bool first: index === 0
            readonly property bool last: index === root.model.length - 1

            role: on ? "secondary" : "paper"
            emphasis: "strong"
            level: 3
            interactive: true
            pressDepth: 0.95
            morph: false
            width: (root.width - root.spacing * (root.model.length - 1)) / root.model.length
            height: 52
            topLeftRadius: on || first ? Tokens.rounding.morph : Math.max(2, Tokens.rounding.small / 2)
            bottomLeftRadius: topLeftRadius
            topRightRadius: on || last ? Tokens.rounding.morph : Math.max(2, Tokens.rounding.small / 2)
            bottomRightRadius: topRightRadius
            onClicked: root.selected(seg.modelData.value)

            Behavior on topLeftRadius {
                Anim {}
            }
            Behavior on topRightRadius {
                Anim {}
            }

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
