pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Nafeel
import qs.config
import qs.services

// Caelestia's cover visualiser: the music as strokes radiating out from a
// circle (the record), longer as each band is louder, in the primary role.
// Listens (ServiceRef) only while it exists and `active`.
Item {
    id: root

    property real innerRadius: 100
    property bool active: true
    property color colour: Colours.roleInk("primary", "ghost")
    readonly property real reach: Math.min(width, height) / 2 - innerRadius - 4

    Loader {
        active: root.active
        sourceComponent: ServiceRef {
            service: Visualiser.cava
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        data: strokes.instances
    }

    Variants {
        id: strokes

        model: Array.from({
            length: Visualiser.bars
        }, (_, i) => i)

        ShapePath {
            id: bar

            required property int modelData
            readonly property real value: Math.max(0.02, Math.min(1, Visualiser.cava.values[modelData] ?? 0))
            readonly property real angle: modelData * 2 * Math.PI / Visualiser.bars - Math.PI / 2
            readonly property real r0: root.innerRadius + 4
            readonly property real r1: r0 + root.reach * value

            strokeWidth: Math.max(2, 2 * Math.PI * root.innerRadius / Visualiser.bars * 0.45)
            strokeColor: Qt.alpha(root.colour, 0.35 + 0.65 * value)
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            startX: root.width / 2 + Math.cos(angle) * r0
            startY: root.height / 2 + Math.sin(angle) * r0

            PathLine {
                x: root.width / 2 + Math.cos(bar.angle) * bar.r1
                y: root.height / 2 + Math.sin(bar.angle) * bar.r1
            }
        }
    }
}
