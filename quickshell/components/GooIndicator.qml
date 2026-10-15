pragma ComponentBehavior: Bound

import QtQuick
import Nafeel
import qs.config

// The bar's goo for any group of items (a button group, a chip row, a tile
// grid): one blob, like the bar's pill. It sits on the selected item, goes to
// the hovered one, and back to the selected when the pointer leaves the
// group; as it moves it parts like ink (a tail stays behind and thins into a
// neck after it). Lay it under the items, filling their container; items are
// found wherever they sit inside it. Labels take their ink from `covers()`.
//
//   GooIndicator { anchors.fill: parent; selected: current; hovered: hoveredItem
//                  fill: …; radius: … }
Item {
    id: root

    // Where the blob rests (null: nowhere, it fades when nothing's hovered).
    property Item selected: null
    // Where the pointer is (null: off the group).
    property Item hovered: null
    property color fill
    // The blob's opacity (the blob ignores a colour's alpha): a faint one
    // laid over items (a tile grid's hover) rather than under their labels.
    property real strength: 1
    // The blobs' corner radius; -1: a pill for each item's size.
    property real radius: -1
    // Shrinks each blob inside its item.
    property real inset: 0

    // Whether the selection blob, where it is right now, covers most of `it`:
    // labels take the selected ink from this, so they turn as the fill
    // arrives and leaves (not when the choice changes: white on white).
    function covers(it: Item): bool {
        if (!it || !selection.at || root.strength < 1)
            return false;
        const r = rectOf(it);
        const ox = Math.max(0, Math.min(r.x + r.width, selection.bx + selection.bw) - Math.max(r.x, selection.bx));
        const oy = Math.max(0, Math.min(r.y + r.height, selection.by + selection.bh) - Math.max(r.y, selection.by));
        return ox * oy > r.width * r.height * 0.5;
    }

    // An item's rectangle here (its geometry read, so the binding follows it).
    function rectOf(it: Item): rect {
        if (!it)
            return Qt.rect(0, 0, 0, 0);
        void (it.x + it.y + it.width + it.height + root.width + root.height);
        const r = root.mapFromItem(it, 0, 0, it.width, it.height);
        return Qt.rect(r.x + inset, r.y + inset, Math.max(0, r.width - inset * 2), Math.max(0, r.height - inset * 2));
    }

    // One blob that springs from item to item, leaving a tail.
    component Mover: Item {
        id: mover

        property Item at: null
        property color colour
        readonly property rect target: root.rectOf(at)
        // The springs run only between items; from nowhere it appears in place.
        property bool glide: false
        property real bx
        property real by
        property real bw
        property real bh

        anchors.fill: parent
        opacity: at ? root.strength : 0

        function place(): void {
            bx = target.x;
            by = target.y;
            bw = target.width;
            bh = target.height;
        }

        onAtChanged: {
            if (!at)
                return;
            if (glide && Tokens.goo.enabled && bw > 1)
                tail.leave(bx, by, bw, bh, target);
            place();
            glide = true;
        }
        onTargetChanged: if (at) place()
        onOpacityChanged: if (opacity === 0) glide = false

        Behavior on opacity {
            Anim {
                duration: Tokens.anim.fast
            }
        }

        BlobGroup {
            id: ink

            color: mover.colour
            smoothing: 10
        }

        // The tail left where it was: pulled after the blob, it thins into
        // a neck toward where the blob went and lets go, the edge facing
        // the blob staying put (ink parting, not a box shrinking).
        BlobRect {
            id: tail

            property rect from
            // Which way the blob went: +1 / -1 along x (sideways) or y.
            property bool sideways: true
            property int dir: 1
            // 0 at the start, 1 gone.
            property real p: 1

            readonly property real lw: sideways ? from.width * (1 - p) : from.width * (1 - 0.7 * p)
            readonly property real lh: sideways ? from.height * (1 - 0.7 * p) : from.height * (1 - p)

            group: p < 1 && width > 2 && height > 2 ? ink : null
            x: sideways ? (dir > 0 ? from.x + from.width - lw : from.x) : from.x + (from.width - lw) / 2
            y: sideways ? from.y + (from.height - lh) / 2 : (dir > 0 ? from.y + from.height - lh : from.y)
            width: lw
            height: lh
            radius: root.radius >= 0 ? Math.min(root.radius, Math.min(width, height) / 2) : Math.min(width, height) / 2
            deformScale: 0

            function leave(lx: real, ly: real, lw: real, lh: real, to: rect): void {
                shrink.stop();
                from = Qt.rect(lx, ly, lw, lh);
                const dx = (to.x + to.width / 2) - (lx + lw / 2);
                const dy = (to.y + to.height / 2) - (ly + lh / 2);
                sideways = Math.abs(dx) >= Math.abs(dy);
                dir = (sideways ? dx : dy) >= 0 ? 1 : -1;
                p = 0;
                shrink.start();
            }

            NumberAnimation {
                id: shrink

                target: tail
                property: "p"
                to: 1
                duration: Tokens.anim.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.anim.emphasizedAccel
            }
        }

        BlobRect {
            id: blob

            group: mover.bw > 1 && mover.bh > 1 ? ink : null
            x: mover.bx
            y: mover.by
            width: mover.bw
            height: mover.bh
            radius: root.radius >= 0 ? Math.min(root.radius, Math.min(width, height) / 2) : Math.min(width, height) / 2
            stiffness: Tokens.goo.stiffness
            damping: Tokens.goo.damping
            // No stretch or tilt along the travel (the user's call: calm ink).
            deformScale: 0
        }

        Behavior on bx {
            enabled: mover.glide
            SpringAnimation {
                spring: Tokens.spring.control.spring
                damping: Tokens.spring.control.damping
                epsilon: 0.25
            }
        }
        Behavior on by {
            enabled: mover.glide
            SpringAnimation {
                spring: Tokens.spring.control.spring
                damping: Tokens.spring.control.damping
                epsilon: 0.25
            }
        }
        Behavior on bw {
            enabled: mover.glide
            SpringAnimation {
                spring: Tokens.spring.control.spring
                damping: Tokens.spring.control.damping
                epsilon: 0.25
            }
        }
        Behavior on bh {
            enabled: mover.glide
            SpringAnimation {
                spring: Tokens.spring.control.spring
                damping: Tokens.spring.control.damping
                epsilon: 0.25
            }
        }
    }

    // Hover: held a moment when the pointer leaves an item, so crossing the
    // gap to the next one glides there instead of fading and reappearing.
    property Item _hoverAt: null
    onHoveredChanged: {
        if (hovered) {
            away.stop();
            _hoverAt = hovered;
        } else {
            away.restart();
        }
    }
    Timer {
        id: away

        interval: 160
        onTriggered: root._hoverAt = null
    }

    Mover {
        id: selection

        colour: root.fill
        at: root._hoverAt ?? root.selected
    }
}
