import QtQuick
import QtQuick.Shapes
import qs.config
import qs.services

// A brush stroke under the caret's line (TextInput or TextEdit; this sits
// inside it): a hairline at the line's start thickening to the caret and
// pooling there, flowing after the caret as it moves; it draws out on focus.
//   TextInput { id: t; TypingBrush { target: t } }
Shape {
    id: root

    required property Item target
    // Where the stroke ends (the caret, springing) and its line's foot.
    property real tip: target.cursorRectangle.x
    property real foot: target.cursorRectangle.y + target.cursorRectangle.height + 1
    property real reach: target.activeFocus ? 1 : 0

    anchors.fill: parent
    visible: enabled && reach > 0.01
    preferredRendererType: Shape.CurveRenderer

    Behavior on tip {
        enabled: !Tokens.reduceMotion
        SpringAnimation {
            spring: Tokens.springK(4)
            damping: Tokens.dampK(0.4)
            epsilon: 0.3
        }
    }
    Behavior on foot {
        enabled: !Tokens.reduceMotion
        SpringAnimation {
            spring: Tokens.springK(4)
            damping: Tokens.dampK(0.4)
            epsilon: 0.3
        }
    }
    Behavior on reach {
        Anim {
            duration: Tokens.anim.normal
        }
    }

    ShapePath {
        id: stroke

        readonly property real x1: Math.max(6, root.tip) * root.reach
        readonly property real y0: Math.min(root.height - 4, root.foot)

        fillColor: Colours.palette.m3primary
        strokeWidth: -1
        startX: 0
        startY: stroke.y0 + 1.5

        PathLine {
            x: stroke.x1 - 3
            y: stroke.y0
        }
        PathArc {
            x: stroke.x1 - 3
            y: stroke.y0 + 4
            radiusX: 2.5
            radiusY: 2
            useLargeArc: true
        }
        PathLine {
            x: 0
            y: stroke.y0 + 2
        }
    }
}
