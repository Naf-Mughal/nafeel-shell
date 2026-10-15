import QtQuick
import qs.config
import qs.services

// A colour to pick: a swatch on the shell's rounding (a Surface: hover, press, keyboard).
// Picked, a ring is drawn round it with a gap, in the theme's ink.
//   Swatch { colour: "#e680a1"; picked: …; onClicked: … }
Surface {
    id: root

    property color colour
    property bool picked
    property real size: 22

    // The ring's draw: 0 none, 1 all the way round.
    property real ring: picked ? 1 : 0
    Behavior on ring {
        enabled: !Tokens.reduceMotion
        Anim {
            duration: Tokens.anim.fast
            easing.bezierCurve: Tokens.anim.emphasizedDecel
        }
    }

    interactive: true
    morph: false
    pressDepth: 0.85
    implicitWidth: size
    implicitHeight: size
    fill: colour
    baseInk: Colours.on(colour)

    // The ring, round the swatch with a gap: it grows out from the edge.
    StyledRect {
        anchors.centerIn: parent
        width: root.width + 8 * root.ring
        height: root.height + 8 * root.ring
        // The swatch's own corners (the rounding setting), plus the gap.
        radius: root.radius + 4 * root.ring
        visible: root.ring > 0.01
        color: "transparent"
        border.width: 2
        border.color: Colours.palette.m3onSurface
        opacity: root.ring
        z: -1
    }
}
