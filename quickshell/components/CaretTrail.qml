import QtQuick
import QtQuick.Shapes
import qs.config
import qs.services

// Kitty's cursor trail (Ryoku turns it on; the user's "sword cut") for a text
// field or area: when the caret jumps (a new line, a word or line move, a
// click, a paste), a tapered streak cuts from where it was to where it went
// and snaps shut. Each corner of the caret chases its place at the new one:
// the corners leading the move get there almost at once, the trailing ones a
// little later, so the streak narrows to the caret. Typing a letter is too
// small a move to cut. Runs only while it moves; reduced motion: none.
//
//   TextEdit { id: edit; CaretTrail { target: edit } }
Shape {
    id: root

    // The TextEdit or TextInput (this sits inside it: its coordinates).
    required property Item target
    property color colour: Colours.palette.m3primary
    // How far the caret must jump to cut, in caret heights.
    property real threshold: 1.2
    // Seconds to settle: the leading corners and the trailing ones.
    property real fast: 0.02 * Tokens.tempo
    property real slow: 0.11 * Tokens.tempo

    // The four corners, now (top left, top right, bottom right, bottom left).
    property var pts: [Qt.point(0, 0), Qt.point(0, 0), Qt.point(0, 0), Qt.point(0, 0)]
    property var goal: pts
    property var taus: [0.1, 0.1, 0.1, 0.1]
    property rect last: Qt.rect(0, 0, 0, 0)

    anchors.fill: parent
    visible: run.running && enabled
    preferredRendererType: Shape.CurveRenderer

    function cornersOf(r: rect): var {
        const w = Math.max(2, r.width);
        return [Qt.point(r.x, r.y), Qt.point(r.x + w, r.y), Qt.point(r.x + w, r.y + r.height), Qt.point(r.x, r.y + r.height)];
    }

    Connections {
        target: root.target

        function onCursorRectangleChanged(): void {
            // Copies: a rect read from a property is a live reference in Qt 6
            // (`was` would turn into the new place as soon as it's stored).
            const c = root.target.cursorRectangle;
            const r = Qt.rect(c.x, c.y, c.width, c.height);
            const was = Qt.rect(root.last.x, root.last.y, root.last.width, root.last.height);
            root.last = r;
            if (!root.enabled || Tokens.reduceMotion || !root.target.activeFocus || was.height === 0)
                return;
            const dx = r.x - was.x;
            const dy = r.y - was.y;
            // The same place again (it's reported twice): nothing moved.
            if (dx === 0 && dy === 0)
                return;
            const far = Math.hypot(dx, dy) > root.threshold * Math.max(8, r.height);
            if (!far && !run.running)
                return;
            if (!run.running)
                root.pts = root.cornersOf(was);
            root.goal = root.cornersOf(r);
            // Leading corners (ahead along the move) fast, trailing ones slow.
            const cx = r.x + r.width / 2, cy = r.y + r.height / 2;
            root.taus = root.goal.map(p => ((p.x - cx) * dx + (p.y - cy) * dy) > 0 ? root.fast : root.slow);
            run.start();
        }
    }

    FrameAnimation {
        id: run

        onTriggered: {
            const dt = Math.min(0.05, frameTime);
            let moving = false;
            const next = [];
            for (let i = 0; i < 4; i++) {
                const p = root.pts[i], g = root.goal[i];
                const k = 1 - Math.exp(-dt / root.taus[i]);
                const nx = p.x + (g.x - p.x) * k, ny = p.y + (g.y - p.y) * k;
                if (Math.abs(g.x - nx) > 0.4 || Math.abs(g.y - ny) > 0.4)
                    moving = true;
                next.push(Qt.point(nx, ny));
            }
            root.pts = next;
            if (!moving)
                stop();
        }
    }

    ShapePath {
        fillColor: root.colour
        fillRule: ShapePath.WindingFill
        strokeWidth: -1
        startX: root.pts[0].x
        startY: root.pts[0].y

        PathLine {
            x: root.pts[1].x
            y: root.pts[1].y
        }
        PathLine {
            x: root.pts[2].x
            y: root.pts[2].y
        }
        PathLine {
            x: root.pts[3].x
            y: root.pts[3].y
        }
        PathLine {
            x: root.pts[0].x
            y: root.pts[0].y
        }
    }
}
