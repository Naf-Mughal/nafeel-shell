pragma ComponentBehavior: Bound

import QtQuick
import Nafeel
import qs.config
import qs.components

// A capsule of bar controls in one colour pair. An active pill (in the
// group's inverse colours, a goo blob) springs to whichever control is
// active: hovered, or showing its popout. Controls take their ink from the group.
Item {
    id: root

    property color fill
    property color ink
    property color pillFill
    property color pillInk
    property real padding: 4
    property real radius: Tokens.rounding.normal

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
            tail.leave(pill.y, pill.height);
        pill.y = c.y + column.y;
        pill.height = c.height;
        pill.at = c;
    }

    Timer {
        id: away

        interval: 220
        onTriggered: pill.at = null
    }

    implicitWidth: Tokens.barWidth - Tokens.spacing.large
    implicitHeight: column.implicitHeight + padding * 2
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
            group: width > 1 && height > 1 ? pillInk : null
            x: pill.x + (pill.width - width) / 2
            width: 0
            height: 0
            radius: Math.min(width / 2, Tokens.rounding.small)
            deformScale: 0

            function leave(fromY: real, fromHeight: real): void {
                shrink.stop();
                y = fromY;
                height = fromHeight;
                width = pill.width;
                shrink.start();
            }

            ParallelAnimation {
                id: shrink

                NumberAnimation {
                    target: tail
                    property: "width"
                    to: 0
                    duration: Tokens.anim.slow
                    easing.bezierCurve: Tokens.anim.emphasizedAccel
                    easing.type: Easing.BezierSpline
                }
                NumberAnimation {
                    target: tail
                    property: "height"
                    to: 0
                    duration: Tokens.anim.slow
                    easing.bezierCurve: Tokens.anim.emphasizedAccel
                    easing.type: Easing.BezierSpline
                }
                NumberAnimation {
                    target: tail
                    property: "y"
                    to: tail.y + tail.height / 2
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

            group: height > 1 ? pillInk : null
            x: root.padding
            width: root.width - root.padding * 2
            y: 0
            height: 0
            radius: Math.min(width / 2, Tokens.rounding.small)
            stiffness: Tokens.goo.stiffness
            damping: Tokens.goo.damping
            deformScale: Tokens.goo.enabled ? Tokens.goo.scale * 3.5 : 0
            maxStretch: 0.3

            Behavior on y {
                enabled: pill.glide
                SpringAnimation {
                    spring: Tokens.springK(4)
                    damping: Tokens.dampK(0.32)
                    epsilon: 0.25
                }
            }
            Behavior on height {
                enabled: pill.glide
                SpringAnimation {
                    spring: Tokens.springK(4)
                    damping: Tokens.dampK(0.32)
                    epsilon: 0.25
                }
            }
        }
    }

    Column {
        id: column

        x: root.padding
        y: root.padding
        width: root.width - root.padding * 2
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
