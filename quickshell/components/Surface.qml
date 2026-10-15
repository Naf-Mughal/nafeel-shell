import QtQuick
import qs.config
import qs.services
import "keynav.js" as KeyNav

// The one container every panel and control is built from. It's made of a
// role (Colours: "paper" at a level, or a colour role at an emphasis), so
// fill and ink always pair the same way; it has a shape preset, an optional
// hairline outline, and, when interactive, the M3 state layer, press bounce
// and the Expressive shape morph (squarer while pressed).
//
//   Surface { role: "primary"; emphasis: "strong"; interactive: true; onClicked: … }
//
// Children read `ink` / `subInk` for their text and icons.
//
// Only an interactive one carries the interaction: its state layer, press
// bounce, handlers and the animations of its fill, radius and scale are made
// with it (a Loader); a still card is just its rectangle. (Every Surface made
// them all: ~2500 surfaces, each a dozen objects, most never touched.)
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
    property real pressDepth: 0.93
    // Rounds tighter while pressed (Expressive shape morph).
    property bool morph: interactive
    // The state layer's hover tint (off where a group's goo shows the hover).
    property bool hoverLayer: true

    // The ink for its role (a control with its own sets `baseInk`); children
    // read `ink` / `subInk`, which on an interactive one fade with the fill.
    property color baseInk: Colours.roleInk(role, emphasis)
    property color baseSubInk: Colours.roleSubInk(role, emphasis)
    property color ink: baseInk
    property color subInk: baseSubInk
    readonly property bool hovered: interaction.item?.hovered ?? false
    readonly property bool pressed: interaction.item?.pressed ?? false
    // Where the last press landed (a toggle's ink fill spreads from here).
    property point pressPoint: Qt.point(width / 2, height / 2)
    readonly property real restRadius: shape === "full" ? Math.min(width, height) / 2 : shape === "small" ? Tokens.rounding.small : shape === "large" ? Tokens.rounding.large : Tokens.rounding.normal
    // The fill for its role, and the radius for its shape (squarer while
    // pressed, the Expressive morph): what it shows; an interactive one
    // animates to them. A control with its own fill or shape sets these, not
    // `color` or `radius`.
    property color fill: Colours.roleFill(role, emphasis, level)
    property real shapeRadius: morph && pressed ? Math.min(restRadius, Tokens.rounding.small * 0.6) : restRadius

    signal clicked
    signal rightClicked
    signal middleClicked

    // For what can't be undone (restart, shut down, …): held, ink spreads
    // from its middle in the theme's colour over `holdMs` and `confirmed`
    // fires when it's full; let go early and it draws back. A click alone
    // sets `hinting` a moment (say "Hold to confirm"). Any interactive one.
    property bool holdToConfirm: false
    property int holdMs: 700
    signal confirmed
    property real hold: 0
    property bool hinting: false
    // Covered by the hold's ink (its ink should turn).
    readonly property bool holding: hold > 0.5

    onPressedChanged: {
        if (!holdToConfirm)
            return;
        if (pressed) {
            holdDrain.stop();
            holdFill.duration = holdMs * (1 - hold);
            holdFill.restart();
        } else if (hold < 1) {
            holdFill.stop();
            holdDrain.restart();
        }
    }
    onClicked: if (holdToConfirm) {
        hinting = true;
        holdHint.restart();
    }
    NumberAnimation {
        id: holdFill

        target: root
        property: "hold"
        to: 1
        onFinished: {
            root.hold = 0;
            root.confirmed();
        }
    }
    NumberAnimation {
        id: holdDrain

        target: root
        property: "hold"
        to: 0
        duration: Tokens.anim.normal
        easing.type: Easing.OutCubic
    }
    Timer {
        id: holdHint

        interval: 1600
        onTriggered: root.hinting = false
    }

    color: fill
    radius: shapeRadius
    // A coloured ghost has a hairline in its role (and a faint wash, Colours):
    // without them it read as empty on dark paper.
    readonly property bool tintedGhost: emphasis === "ghost" && role !== "paper"
    border.width: keyFocused ? 2 : outlined || tintedGhost ? Tokens.hairline : 0
    border.color: keyFocused ? Colours.palette.m3primary : tintedGhost ? Qt.alpha(Colours.roleInk(role, "ghost"), 0.4) : Qt.alpha(Colours.palette.m3onSurface, 0.13)

    // The keyboard: an interactive surface takes it from Tab and the arrows
    // (within its panel, KeyNav), Enter or Space presses it; the ring shows
    // only when the keyboard put it there, not after a click.
    readonly property bool keyFocused: activeFocus && interactive && focusByKey
    property bool focusByKey: false
    activeFocusOnTab: interactive
    onActiveFocusChanged: {
        if (!activeFocus)
            focusByKey = false;
    }
    Keys.onPressed: event => {
        if (!interactive)
            return;
        switch (event.key) {
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            root.clicked();
            break;
        case Qt.Key_Down:
        case Qt.Key_Right:
        case Qt.Key_Tab:
            KeyNav.move(root, true);
            break;
        case Qt.Key_Up:
        case Qt.Key_Left:
        case Qt.Key_Backtab:
            KeyNav.move(root, false);
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    // The hold's ink, under the content.
    InkSpread {
        visible: root.holdToConfirm && p > 0.001
        color: Colours.roleFill("primary", "strong", 0)
        origin: Qt.point(root.width / 2, root.height / 2)
        p: root.hold
        r1: root.radius
    }

    Loader {
        id: interaction

        anchors.fill: parent
        active: root.interactive
        sourceComponent: Item {
            id: ix

            readonly property bool hovered: hover.hovered
            readonly property bool pressed: tap.pressed

            // The fill fades between states (checked, selected, …).
            property color fill: root.fill
            Behavior on fill {
                CAnim {}
            }
            Binding {
                target: root
                property: "color"
                value: ix.fill
                restoreMode: Binding.RestoreBindingOrValue
            }

            // Its ink, in step with the fill (text snapping to the new state
            // while the fill still faded briefly lost its contrast).
            property color ink: root.baseInk
            property color subInk: root.baseSubInk
            Behavior on ink {
                CAnim {}
            }
            Behavior on subInk {
                CAnim {}
            }
            Binding {
                target: root
                property: "ink"
                value: ix.ink
                restoreMode: Binding.RestoreBindingOrValue
            }
            Binding {
                target: root
                property: "subInk"
                value: ix.subInk
                restoreMode: Binding.RestoreBindingOrValue
            }

            // The shape, animated (the Expressive morph while pressed).
            property real shapeRadius: root.shapeRadius
            Behavior on shapeRadius {
                Anim {
                    duration: Tokens.anim.fast
                    easing.bezierCurve: Tokens.anim.expressiveFastSpatial
                }
            }
            Binding {
                target: root
                property: "radius"
                value: ix.shapeRadius
                restoreMode: Binding.RestoreBindingOrValue
            }

            // Press physics: a squash that springs back past rest.
            property real bounce: pressed ? root.pressDepth : 1
            Behavior on bounce {
                SpringAnimation {
                    spring: Tokens.spring.bouncy.spring
                    damping: Tokens.spring.bouncy.damping
                    epsilon: 0.002
                }
            }
            Binding {
                target: root
                property: "scale"
                value: ix.bounce
                restoreMode: Binding.RestoreBindingOrValue
            }

            // The press: ink spreading from where it landed, fading on release.
            InkSpread {
                id: ripple

                color: root.ink
                opacity: 0
                origin: root.pressPoint
                r1: root.radius

                Connections {
                    target: ix

                    function onPressedChanged(): void {
                        if (ix.pressed) {
                            fade.stop();
                            ripple.opacity = 0.14;
                            spread.restart();
                        } else {
                            fade.restart();
                        }
                    }
                }
                NumberAnimation {
                    id: spread

                    target: ripple
                    property: "p"
                    from: 0
                    to: 1
                    duration: Tokens.anim.normal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.anim.emphasizedDecel
                }
                NumberAnimation {
                    id: fade

                    target: ripple
                    property: "opacity"
                    to: 0
                    duration: Tokens.anim.normal
                    easing.type: Easing.OutQuad
                }
            }

            StateLayer {
                hovered: (ix.hovered && root.hoverLayer) || root.keyFocused
                pressed: false
                ink: root.ink
                // The surface's shape (its parent here is this holder).
                radius: root.radius
                topLeftRadius: root.topLeftRadius
                topRightRadius: root.topRightRadius
                bottomLeftRadius: root.bottomLeftRadius
                bottomRightRadius: root.bottomRightRadius
            }

            HoverHandler {
                id: hover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                id: tap

                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onPressedChanged: if (pressed)
                    root.pressPoint = point.position
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
    }
}
