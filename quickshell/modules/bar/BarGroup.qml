pragma ComponentBehavior: Bound

import QtQuick
import Nafeel
import qs.config
import qs.components

// A capsule of bar controls in one colour pair. An active pill (in the
// group's inverse colours, a goo blob) springs to whichever control is
// active: hovered, or showing its popout. Controls take their ink from the group.
// Down a vertical bar, or across a `horizontal` one.
Item {
    id: root

    property color fill
    property color ink
    property color pillFill
    property color pillInk
    property real padding: 4
    property real radius: Tokens.rounding.normal
    property bool horizontal: false
    // The capsule's thickness across the bar.
    readonly property real cross: Tokens.barWidth - Tokens.spacing.large

    default property alias controls: column.data

    // The active control: a hovered one wins over one whose popout is open.
    readonly property Item activeControl: {
        const items = column.children;
        let open = null;
        for (let i = 0; i < items.length; i++) {
            // A plugin's control arrives in a Loader: look at what it holds,
            // place the pill by the Loader.
            const c = items[i];
            const ctl = c.active !== undefined && c.hovered !== undefined ? c : c.item;
            if (!c.visible || !ctl || ctl.active === undefined || !ctl.visible)
                continue;
            if (ctl.hovered)
                return c;
            if (ctl.active)
                open = c;
        }
        return open;
    }

    // Moves the pill: between controls it springs and leaves a tail; from
    // nowhere it appears in place; leaving, it stays put while it fades.
    onActiveControlChanged: {
        const c = activeControl;
        if (!c) {
            away.restart();
            return;
        }
        away.stop();
        if (pill.at === c)
            return;
        const from = pill.at;
        pill.glide = from !== null;
        if (from && Tokens.goo.enabled)
            tail.leave(pill.along, pill.length);
        pill.along = horizontal ? c.x + column.x : c.y + column.y;
        pill.length = horizontal ? c.width : c.height;
        pill.at = c;
    }

    Timer {
        id: away

        interval: 220
        onTriggered: pill.at = null
    }

    implicitWidth: horizontal ? column.implicitWidth + padding * 2 : cross
    implicitHeight: horizontal ? cross : column.implicitHeight + padding * 2
    // No self-hiding from its children's visibility: an item counts as
    // invisible while its parent is hidden, so a group that hid itself while
    // the bar was hidden (fullscreen, lock) would never come back. Hide a
    // group explicitly where it can really be empty.

    StyledRect {
        anchors.fill: parent
        radius: root.radius
        color: root.fill
    }

    // The active pill: a goo blob (the frame's engine) that springs to the
    // active control, stretching along its travel and settling with a little
    // squash. Moving on, it splits: a tail stays behind and shrinks away while
    // the pill leaves, the two joined by a neck that thins and snaps.
    Item {
        anchors.fill: parent
        opacity: pill.at ? 1 : 0

        Behavior on opacity {
            Anim {
                duration: Tokens.anim.fast
            }
        }

        BlobGroup {
            id: pillInk

            color: root.pillFill
            smoothing: 10
        }

        // The tail left behind where the pill was.
        BlobRect {
            id: tail

            // Only drawn while it has real size: a sliver on its way to
            // nothing would show as a hairline across the bar.
            // Along the bar and across it (y and height down a vertical
            // bar, x and width across a horizontal one).
            property real along: 0
            property real length: 0
            property real breadth: 0

            group: length > 1 && breadth > 1 ? pillInk : null
            x: root.horizontal ? along : root.padding + (root.width - root.padding * 2 - breadth) / 2
            y: root.horizontal ? root.padding + (root.height - root.padding * 2 - breadth) / 2 : along
            width: root.horizontal ? length : breadth
            height: root.horizontal ? breadth : length
            radius: Math.min(breadth / 2, Tokens.rounding.small)
            deformScale: 0

            function leave(fromAlong: real, fromLength: real): void {
                shrink.stop();
                along = fromAlong;
                length = fromLength;
                breadth = root.horizontal ? root.height - root.padding * 2 : root.width - root.padding * 2;
                shrink.start();
            }

            ParallelAnimation {
                id: shrink

                NumberAnimation {
                    target: tail
                    property: "breadth"
                    to: 0
                    duration: Tokens.anim.slow
                    easing.bezierCurve: Tokens.anim.emphasizedAccel
                    easing.type: Easing.BezierSpline
                }
                NumberAnimation {
                    target: tail
                    property: "length"
                    to: 0
                    duration: Tokens.anim.slow
                    easing.bezierCurve: Tokens.anim.emphasizedAccel
                    easing.type: Easing.BezierSpline
                }
                NumberAnimation {
                    target: tail
                    property: "along"
                    to: tail.along + tail.length / 2
                    duration: Tokens.anim.slow
                    easing.bezierCurve: Tokens.anim.emphasizedAccel
                    easing.type: Easing.BezierSpline
                }
            }
        }

        BlobRect {
            id: pill

            // The control it's on: kept through the brief gap while the
            // pointer crosses from one control to the next (cleared only
            // after `away`), so it springs across instead of jumping.
            property Item at: null
            // Whether the next move springs (between controls) or is instant
            // (appearing from nowhere).
            property bool glide: false

            property real along: 0
            property real length: 0

            group: length > 1 ? pillInk : null
            x: root.horizontal ? along : root.padding
            y: root.horizontal ? root.padding : along
            width: root.horizontal ? length : root.width - root.padding * 2
            height: root.horizontal ? root.height - root.padding * 2 : length
            radius: Math.min((root.horizontal ? height : width) / 2, Tokens.rounding.small)
            stiffness: Tokens.goo.stiffness
            damping: Tokens.goo.damping
            deformScale: Tokens.goo.enabled ? Tokens.goo.scale * 3.5 : 0
            maxStretch: 0.3

            Behavior on along {
                enabled: pill.glide
                SpringAnimation {
                    spring: Tokens.springK(4)
                    damping: Tokens.dampK(0.32)
                    epsilon: 0.25
                }
            }
            Behavior on length {
                enabled: pill.glide
                SpringAnimation {
                    spring: Tokens.springK(4)
                    damping: Tokens.dampK(0.32)
                    epsilon: 0.25
                }
            }
        }
    }

    Grid {
        id: column

        x: root.padding
        y: root.padding
        width: root.horizontal ? implicitWidth : root.width - root.padding * 2
        height: root.horizontal ? root.height - root.padding * 2 : implicitHeight
        // One column down a vertical bar, one row across a horizontal one.
        columns: root.horizontal ? 64 : 1
        spacing: 2

        // Controls take the group's ink (and the pill's while active).
        onChildrenChanged: {
            for (const c of children) {
                if ("groupInk" in c) {
                    c.groupInk = Qt.binding(() => root.ink);
                    c.groupActiveInk = Qt.binding(() => root.pillInk);
                }
            }
        }
    }
}
