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
    property real pressDepth: 0.96
    // Rounds tighter while pressed (Expressive shape morph).
    property bool morph: interactive

    // The ink for its role (a control with its own sets `baseInk`); children
    // read `ink` / `subInk`, which on an interactive one fade with the fill.
    property color baseInk: Colours.roleInk(role, emphasis)
    property color baseSubInk: Colours.roleSubInk(role, emphasis)
    property color ink: baseInk
    property color subInk: baseSubInk
    readonly property bool hovered: interaction.item?.hovered ?? false
    readonly property bool pressed: interaction.item?.pressed ?? false
    readonly property real restRadius: shape === "full" ? Math.min(width, height) / 2 : shape === "small" ? Tokens.rounding.small : shape === "large" ? Tokens.rounding.large : Tokens.rounding.normal
    // The fill for its role, and the radius for its shape (squarer while
    // pressed, the Expressive morph): what it shows; an interactive one
    // animates to them. A control with its own fill or shape sets these, not
    // `color` or `radius`.
    property color fill: Colours.roleFill(role, emphasis, level)
    property real shapeRadius: morph && pressed ? Math.min(restRadius, Tokens.rounding.small) : restRadius

    signal clicked
    signal rightClicked
    signal middleClicked

    color: fill
    radius: shapeRadius
    border.width: keyFocused ? 2 : outlined ? Tokens.hairline : 0
    border.color: keyFocused ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3onSurface, 0.13)

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

            StateLayer {
                hovered: ix.hovered || root.keyFocused
                pressed: ix.pressed
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
