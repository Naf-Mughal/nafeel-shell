import QtQuick
import qs.config

// The M3 state layer: a tint of the control's own ink over it, 8% while
// hovered and 12% while pressed, following its shape.
Rectangle {
    property bool hovered
    property bool pressed
    property color ink

    anchors.fill: parent
    radius: parent.radius ?? 0
    topLeftRadius: parent.topLeftRadius ?? radius
    topRightRadius: parent.topRightRadius ?? radius
    bottomLeftRadius: parent.bottomLeftRadius ?? radius
    bottomRightRadius: parent.bottomRightRadius ?? radius
    color: ink
    opacity: pressed ? 0.12 : hovered ? 0.08 : 0

    Behavior on opacity {
        Anim {
            duration: Tokens.anim.hover
        }
    }
}
