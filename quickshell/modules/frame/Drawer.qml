pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// A drawer, drawn as part of the frame's shape (FrameWindow draws each one as
// a BlobRect merged into the frame's BlobGroup). The frame is four bars and four corners, and a drawer
// anchors to either:
//   a bar     (edge "left" | "top" | "right" | "bottom") slides out of it at
//             `along` (0..1)
//   a corner  (edge "corner", `corner` "topLeft" | "topRight" | "bottomLeft" |
//             "bottomRight") grows out of the corner point in both directions
//             at once, merged into both bars it touches (`thickness` is the
//             vertical bar's, `thicknessY` the horizontal one's), so the
//             session corner reads as part of the left bar
// Fill it with content as children; they're laid out at the open size and
// come out with the drawer (from the corner, for a corner).
//
// It opens by hover (ShellState.preview) from its own hot zone (the bar strip
// under it, or a square in its corner) when `hoverZone` is set, or from any
// trigger that calls ShellState.preview(name, screen); a press inside pins it.
Item {
    id: root

    required property string name
    required property string edge // "bottom" | "top" | "left" | "right" | "corner"
    // Frame thickness on that edge (the bar's width for "left"); for a corner,
    // the vertical bar's.
    required property real thickness
    // For a corner: which one, and the horizontal bar's thickness.
    property string corner: "bottomRight"
    property real thicknessY: thickness
    required property ShellScreen shellScreen

    // Size when open, and where its centre sits along the edge (0..1).
    property int panelWidth: 400
    property int panelHeight: 300
    property real along: 0.5
    property bool hoverZone: true
    property bool wantsKeyboard: false
    // The ShellState name hovering or pressing inside keeps open; a drawer
    // shared by several triggers (the bar popout) points it at the current one.
    property string key: name
    // Whether a press inside pins it.
    property bool pinOnPress: true
    // The hover strip's length while closed (0 = the drawer's own span); for
    // a corner, the side of its hot square.

    property real zoneLength: 0
    // Off for drawers that open by themselves (toasts): no hover/pin through
    // ShellState.
    property bool managed: true

    default property alias content: body.data

    readonly property string screenName: shellScreen?.name ?? ""
    property bool open: enabled && ShellState.isOpen(name, screenName)
    readonly property bool pinned: open && ShellState.pinned === key
    readonly property bool isCorner: edge === "corner"
    readonly property bool cornerRight: corner.endsWith("Right")
    readonly property bool cornerBottom: corner.startsWith("bottom")
    readonly property bool vertical: edge === "bottom" || edge === "top"
    readonly property real depth: vertical ? panelHeight : panelWidth
    property real prog: open ? 1 : 0
    // A corner grows out of its corner point in both directions at once, a
    // spring on each axis (the width a touch brisker, so it blooms rather
    // than scales), and shrinks back into the corner the same way.
    property real progX: open ? 1 : 0
    property real progY: open ? 1 : 0
    readonly property real shown: depth * Math.max(0, prog)
    readonly property bool active: prog > 0.002 || (isCorner && (progX > 0.002 || progY > 0.002))

    // Input/hover area: the border strip plus the part that's out.
    readonly property rect region: Qt.rect(shape.x, shape.y, shape.width, shape.height)
    // The blob that draws this drawer (FrameWindow's BlobRect for it sets
    // itself here) and its squash and stretch: Ryoku's BlobRect spring, in
    // C++, pinned at `goo` (the side it grows out of: a corner's corner, an
    // edge drawer's bar side), so only its free edge springs and it stays
    // part of the bar. The content gets the same transform.
    property Item blob: null
    readonly property point goo: isCorner ? Qt.point(cornerRight ? 1 : -1, cornerBottom ? 1 : -1) : edge === "left" ? Qt.point(-1, 0) : edge === "right" ? Qt.point(1, 0) : edge === "top" ? Qt.point(0, -1) : Qt.point(0, 1)
    readonly property matrix4x4 deform: blob ? blob.rawDeformMatrix : Qt.matrix4x4()

    // How far out it is (0..1), and the content's fade: in over the first
    // third, so it never pops.
    readonly property real emerge: Math.max(0, Math.min(1, isCorner ? Math.min(progX, progY) : prog))
    readonly property real inked: Math.min(1, emerge * 3)
    // The ink soaking into the paper, on its own pace (a spring's travel is
    // mostly over in its first tenth of a second, too quick to see): once
    // from empty each time the content arrives (opening, or switching to
    // other content: resoak()), receding on close.
    property real soak: 0

    function resoak(): void {
        soakOut.stop();
        soakIn.restart();
    }

    onOpenChanged: {
        if (open) {
            resoak();
        } else {
            soakIn.stop();
            soakOut.restart();
        }
    }

    NumberAnimation {
        id: soakIn

        target: root
        property: "soak"
        from: 0
        to: 1
        // An even spread (not front-loaded, or it's over before it shows).
        duration: Tokens.dur(900)
        easing.type: Easing.InOutQuad
    }

    NumberAnimation {
        id: soakOut

        target: root
        property: "soak"
        to: 0
        duration: Tokens.anim.normal
        easing.type: Easing.InOutQuad
    }

    // Which corners are round (top-left, top-right, bottom-right,
    // bottom-left): only those facing the desktop; the sides it grows out of
    // are square so they melt into the frame.
    readonly property vector4d radii: {
        const r = Tokens.rounding.large;
        if (isCorner)
            return Qt.vector4d(corner === "bottomRight" ? r : 0, corner === "bottomLeft" ? r : 0, corner === "topLeft" ? r : 0, corner === "topRight" ? r : 0);
        switch (edge) {
        case "left":
            return Qt.vector4d(0, r, r, 0);
        case "right":
            return Qt.vector4d(r, 0, 0, r);
        case "top":
            return Qt.vector4d(0, 0, r, r);
        default:
            return Qt.vector4d(r, r, 0, 0);
        }
    }

    anchors.fill: parent

    Behavior on prog {
        SpringAnimation {
            spring: Tokens.spring.spatial.spring
            damping: Tokens.spring.spatial.damping
            epsilon: 0.002
        }
    }
    Behavior on progX {
        enabled: root.isCorner
        SpringAnimation {
            spring: Tokens.spring.spatial.spring * 1.12
            damping: Tokens.spring.spatial.damping
            epsilon: 0.002
        }
    }
    Behavior on progY {
        enabled: root.isCorner
        SpringAnimation {
            spring: Tokens.spring.spatial.spring
            damping: Tokens.spring.spatial.damping
            epsilon: 0.002
        }
    }

    Item {
        id: shape

        // A bar drawer's length along its bar, and where it starts.
        readonly property real span: !root.active && root.zoneLength > 0 ? root.zoneLength : root.vertical ? root.panelWidth : root.panelHeight
        readonly property real start: {
            const total = root.vertical ? root.width : root.height;
            return Math.max(0, Math.min(total - span, total * root.along - span / 2));
        }
        // A corner drawer grows with progX/progY straight out of the bar and
        // border it's part of (no separate seed: it starts flush with them);
        // closed, it's its hot square.
        readonly property real cornerW: root.thickness + (root.active ? root.panelWidth * Math.max(0, root.progX) : root.zoneLength || 40)
        readonly property real cornerH: root.thicknessY + (root.active ? root.panelHeight * Math.max(0, root.progY) : root.zoneLength || 40)

        x: root.isCorner ? (root.cornerRight ? root.width - cornerW : 0) : root.vertical ? start : root.edge === "left" ? 0 : root.width - root.thickness - root.shown
        y: root.isCorner ? (root.cornerBottom ? root.height - cornerH : 0) : !root.vertical ? start : root.edge === "top" ? 0 : root.height - root.thickness - root.shown
        width: root.isCorner ? cornerW : root.vertical ? span : root.thickness + root.shown
        height: root.isCorner ? cornerH : root.vertical ? root.thickness + root.shown : span
        clip: true

        HoverHandler {
            enabled: root.managed && root.enabled && (root.hoverZone || root.active)
            onHoveredChanged: {
                if (hovered)
                    ShellState.preview(root.key, root.screenName);
                else
                    ShellState.unpreviewLater(root.key);
            }
            onPointChanged: {
                if (hovered && root.open)
                    ShellState.keep(root.key);
            }
        }

        // A press inside pins it (passive: children still get it). Not on the
        // bar or frame strip it grows out of: a click on a bar icon there
        // pins or unpins through the icon itself, and pinning here first made
        // that click toggle the panel closed.
        PointHandler {
            id: pressInside

            enabled: root.managed && root.open && root.pinOnPress
            onActiveChanged: {
                if (!active)
                    return;
                const p = point.pressPosition;
                const onStrip = root.isCorner ? (root.cornerRight ? p.x > shape.width - root.thickness : p.x < root.thickness) || (root.cornerBottom ? p.y > shape.height - root.thicknessY : p.y < root.thicknessY) : root.edge === "left" ? p.x < root.thickness : root.edge === "right" ? p.x > shape.width - root.thickness : root.edge === "top" ? p.y < root.thickness : p.y > shape.height - root.thickness;
                if (!onStrip)
                    ShellState.pin(root.key, root.screenName);
            }
        }

        // The part of the stretch that's out of the bar: the content is
        // clipped to it, so it appears exactly at the bar's edge and rides
        // out on it (never from behind the bar's icons).
        Item {
            id: out

            readonly property bool barLeft: root.isCorner ? !root.cornerRight : root.edge === "left"
            readonly property bool barRight: root.isCorner ? root.cornerRight : root.edge === "right"

            readonly property bool stripTop: root.isCorner ? !root.cornerBottom : root.edge === "top"
            readonly property bool stripBottom: root.isCorner ? root.cornerBottom : root.edge === "bottom"
            readonly property real stripH: root.isCorner ? root.thicknessY : root.thickness

            x: barLeft ? root.thickness : 0
            y: stripTop ? stripH : 0
            width: shape.width - (barLeft || barRight ? root.thickness : 0)
            height: shape.height - (stripTop || stripBottom ? stripH : 0)
            clip: true

            // The blob's squash and stretch (pinned at the bar side), about
            // the blob's centre in this item's coordinates.
            readonly property real cx: shape.width / 2 - x
            readonly property real cy: shape.height / 2 - y
            readonly property matrix4x4 m: root.deform

            // The content soaks out from the side it grows from, like ink
            // into paper, keeping pace with the paper (only while revealing:
            // nothing extra at rest).
            layer.enabled: root.active && root.soak < 0.999 && Tokens.goo.enabled
            layer.effect: ShaderEffect {
                property real progress: root.soak
                property vector2d origin: Qt.vector2d((root.goo.x + 1) / 2, (root.goo.y + 1) / 2)
                property vector2d size: Qt.vector2d(out.width, out.height)

                fragmentShader: Qt.resolvedUrl("../../shaders/soak.frag.qsb")
            }

            transform: Matrix4x4 {
                matrix: Qt.matrix4x4(out.m.m11, out.m.m12, 0, out.cx + out.m.m14 - out.m.m11 * out.cx - out.m.m12 * out.cy, out.m.m21, out.m.m22, 0, out.cy + out.m.m24 - out.m.m21 * out.cx - out.m.m22 * out.cy, 0, 0, 1, 0, 0, 0, 0, 1)
            }

            Item {
                id: body

                // On the moving edges: it rides out with them (a corner's with
                // its free corner, both ways at once).
                x: out.barLeft ? out.width - root.panelWidth : 0
                y: out.stripTop ? out.height - root.panelHeight : 0
                width: root.panelWidth
                height: root.panelHeight
                // Reduced motion: a plain fade instead of the soak.
                opacity: Tokens.goo.enabled ? 1 : root.inked
                visible: opacity > 0 && root.active && root.emerge > 0
            }
        }
    }
}
