import QtQuick
import qs.config
import qs.services

// The one container every panel and control is built from. It's made of a
// role (Colours: "paper" at a level, or a colour role at an emphasis), so
// fill and ink always pair the same way; it has a shape preset, an optional
// hairline outline, and, when interactive, the M3 state layer, press bounce
// and the Expressive shape morph (squarer while pressed).
//
//   Surface { role: "primary"; emphasis: "strong"; interactive: true; onClicked: … }
//
// Children read `ink` / `subInk` for their text and icons.
StyledRect {
    id: root

    property string role: "paper"
    property string emphasis: "soft"
    // Paper's level: 0 lowest .. 4 highest (3: the usual card).
    property int level: 3
    // "small" | "normal" | "large" | "full" (a pill); set `radius` to override.
    property string shape: "normal"
    property bool outlined: false
    property bool interactive: false
    // The squash while pressed (1 = none).
    property real pressDepth: 0.96
    // Rounds tighter while pressed (Expressive shape morph).
    property bool morph: interactive

    property color ink: Colours.roleInk(role, emphasis)
    property color subInk: Colours.roleSubInk(role, emphasis)
    readonly property bool hovered: hover.hovered
    readonly property bool pressed: tap.pressed
    readonly property real restRadius: shape === "full" ? Math.min(width, height) / 2 : shape === "small" ? Tokens.rounding.small : shape === "large" ? Tokens.rounding.large : Tokens.rounding.normal

    signal clicked
    signal rightClicked
    signal middleClicked

    color: Colours.roleFill(role, emphasis, level)
    radius: morph && pressed ? Math.min(restRadius, Tokens.rounding.small) : restRadius
    border.width: outlined ? Tokens.hairline : 0
    border.color: Qt.alpha(Colours.palette.m3onSurface, 0.13)

    Behavior on radius {
        Anim {
            duration: Tokens.anim.fast
            easing.bezierCurve: Tokens.anim.expressiveFastSpatial
        }
    }
    Behavior on scale {
        SpringAnimation {
            spring: Tokens.spring.bouncy.spring
            damping: Tokens.spring.bouncy.damping
            epsilon: 0.002
        }
    }

    StateLayer {
        visible: root.interactive
        hovered: root.hovered
        pressed: root.pressed
        ink: root.ink
    }

    PressBounce {
        pressed: root.interactive && root.pressed
        depth: root.pressDepth
    }

    HoverHandler {
        id: hover

        enabled: root.interactive
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: tap

        enabled: root.interactive
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onTapped: (eventPoint, button) => {
            if (button === Qt.RightButton)
                root.rightClicked();
            else if (button === Qt.MiddleButton)
                root.middleClicked();
            else
                root.clicked();
        }
    }
}
