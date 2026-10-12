import QtQuick
import QtQuick.Shapes
import qs.config
import qs.services

// An M3 circular progress (Caelestia's, on the shell's roles): the value as an
// arc in `fg`, a gap, the rest as a softer track. `startAngle`/`sweepAngle` in
// degrees (0 = 3 o'clock, clockwise); a 270° gauge is (-225, 270).
// Children sit in the middle.
//
//   CircularProgress { value: 0.4; startAngle: -225; sweepAngle: 270 }
Item {
    id: root

    property real value
    property real startAngle: -90
    property real sweepAngle: 360
    property real strokeWidth: 6
    property real gap: 6
    property color fg: Colours.roleInk("primary", "ghost")
    property color track: Colours.roleFill("secondary", "soft", 0)
    property real implicitSize: 64

    property real shown: Math.max(1 / 360, Math.min(1, isNaN(value) ? 0 : value))
    readonly property real radius: (Math.min(width, height) - strokeWidth) / 2
    readonly property real gapAngle: (gap + strokeWidth) / Math.max(1, radius) * 180 / Math.PI
    readonly property bool full: sweepAngle >= 360

    implicitWidth: implicitSize
    implicitHeight: implicitSize

    Behavior on shown {
        Anim {}
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // The rest, after a gap.
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.track
            strokeWidth: root.strokeWidth
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: root.startAngle + root.shown * root.sweepAngle + root.gapAngle
                sweepAngle: Math.max(0.01, root.sweepAngle * (1 - root.shown) - root.gapAngle * (root.full ? 2 : 1))
            }
        }

        // The value.
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.fg
            strokeWidth: root.strokeWidth
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: root.startAngle
                sweepAngle: root.shown * root.sweepAngle
            }
        }
    }
}
