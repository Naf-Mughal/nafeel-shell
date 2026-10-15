import QtQuick
import qs.config
import qs.services
import Nafeel
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
// Only an interactive one carries the interaction, and natively (SurfaceFx,
// in the Nafeel module): a still card is just its rectangle and one inert
// item. (In QML every interactive surface made ~25 objects for it: ~40 MB
// over the warm panels.)
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
    readonly property bool hovered: fx.hovered
    // Where the pointer is on it while hovered (HoverTracker's dead zones).
    readonly property point hoverAt: fx.hoverAt
    // The pointer in the window, as the event had it (no item's transform in
    // it: a drawer squashing as it resizes doesn't make a still pointer move).
    readonly property point hoverScene: fx.hoverScene
    readonly property bool pressed: fx.pressed
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

    // The interaction, native (Nafeel's SurfaceFx): an interactive one's
    // state layer, press ripple and bounce, the shape morph, its fill and
    // ink fading between states, hold to confirm; it owns the surface's
    // color, ink, subInk, radius and scale while interactive (as Bindings
    // would), and is one inert item on a still card. In QML that was ~25
    // objects a surface, ~40 MB over the warm panels.
    SurfaceFx {
        id: fx
    }
}
