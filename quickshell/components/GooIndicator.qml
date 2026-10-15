pragma ComponentBehavior: Bound

import QtQuick
import Nafeel
import qs.config

// The bar's goo for any group of items (a button group, a chip row, a tile
// grid): a blob that springs to the selected item, stretching along its
// travel, and splits as it goes (a tail stays where it was and shrinks away,
// joined by a neck that thins and snaps); and a fainter one that follows the
// hovered item the same way. Lay it under the items, filling their
// container; items are found wherever they sit inside it.
//
//   GooIndicator { anchors.fill: parent; selected: current; hovered: hoveredItem
//                  fill: …; hoverFill: …; radius: … }
Item {
    id: root

    // The item the selection blob sits on (null: none, it fades).
    property Item selected: null
    // The item the hover blob sits on (null: none). A hover on the selected
    // item shows nothing more.
    property Item hovered: null
    property color fill
    property color hoverFill
    // The blobs' corner radius; -1: a pill for each item's size.
    property real radius: -1
    // Shrinks each blob inside its item.
    property real inset: 0

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
        opacity: at ? 1 : 0

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
                tail.leave(bx, by, bw, bh);
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

        // The tail left where it was.
        BlobRect {
            id: tail

            group: width > 1 && height > 1 ? ink : null
            radius: root.radius >= 0 ? Math.min(root.radius, Math.min(width, height) / 2) : Math.min(width, height) / 2
            deformScale: 0

            function leave(lx: real, ly: real, lw: real, lh: real): void {
                shrink.stop();
                x = lx;
                y = ly;
                width = lw;
                height = lh;
                shrinkX.to = lx + lw / 2;
                shrinkY.to = ly + lh / 2;
                shrink.start();
            }

            ParallelAnimation {
                id: shrink

                NumberAnimation {
                    target: tail
                    property: "width"
                    to: 0
                    duration: Tokens.anim.slow
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.anim.emphasizedAccel
                }
                NumberAnimation {
                    target: tail
                    property: "height"
                    to: 0
                    duration: Tokens.anim.slow
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.anim.emphasizedAccel
                }
                NumberAnimation {
                    id: shrinkX

                    target: tail
                    property: "x"
                    duration: Tokens.anim.slow
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.anim.emphasizedAccel
                }
                NumberAnimation {
                    id: shrinkY

                    target: tail
                    property: "y"
                    duration: Tokens.anim.slow
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.anim.emphasizedAccel
                }
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
            deformScale: Tokens.goo.enabled ? Tokens.goo.scale * 3.5 : 0
            maxStretch: 0.3
        }

        Behavior on bx {
            enabled: mover.glide
            SpringAnimation {
                spring: Tokens.springK(4)
                damping: Tokens.dampK(0.32)
                epsilon: 0.25
            }
        }
        Behavior on by {
            enabled: mover.glide
            SpringAnimation {
                spring: Tokens.springK(4)
                damping: Tokens.dampK(0.32)
                epsilon: 0.25
            }
        }
        Behavior on bw {
            enabled: mover.glide
            SpringAnimation {
                spring: Tokens.springK(4)
                damping: Tokens.dampK(0.32)
                epsilon: 0.25
            }
        }
        Behavior on bh {
            enabled: mover.glide
            SpringAnimation {
                spring: Tokens.springK(4)
                damping: Tokens.dampK(0.32)
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
        colour: root.hoverFill
        at: root._hoverAt && root._hoverAt !== root.selected ? root._hoverAt : null
    }

    Mover {
        colour: root.fill
        at: root.selected
    }
}
