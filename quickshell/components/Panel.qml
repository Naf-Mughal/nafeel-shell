import QtQuick
import qs.config

// The root of a panel: its heading (when it has a title) and then its
// sections, on the panel rhythm. Everything else a panel needs comes from the
// frame: where it grows from, the morph between panels sharing a corner, the
// joins into the bars, and the ink-soak reveal.
//
//   Panel {
//       icon: "volume_up"; title: "Sound"; gloss: Xian.gloss.audio; subtitle: "…"
//       Surface { … }   // the sections, top to bottom
//   }
Column {
    id: root

    property string icon
    property string title
    property string gloss
    property string subtitle
    // "comfortable" (the usual) | "compact" (dense lists).
    property string density: "comfortable"
    property alias actions: header.trailing
    property alias middle: header.middle
    // What gets the keyboard when the panel is pinned (a search field, say);
    // CornerPopout hands it over.
    property Item focusTarget: null

    function takeFocus(): bool {
        if (!focusTarget)
            return false;
        if (focusTarget.focusInput)
            focusTarget.focusInput();
        else
            focusTarget.forceActiveFocus();
        return true;
    }

    spacing: density === "compact" ? Tokens.spacing.small : Tokens.spacing.normal

    // The sections' entrance as the panel opens (Appearance → Contents):
    // "together" leaves it to the frame's soak; "stagger" raises them one
    // after another; "ink" sweeps them in from the left. Each section gets a
    // Translate the first time (kept), and its animation lives only while
    // it plays.
    onVisibleChanged: if (visible)
        enter()

    // Each section's Translate (an item takes no new properties from JS).
    property var _shifts: new Map()

    function enter(): void {
        const mode = Tokens.contents;
        if (mode === "together" || Tokens.reduceMotion)
            return;
        let i = 0;
        for (const c of children) {
            if (!c.visible || c.height <= 0)
                continue;
            let t = _shifts.get(c);
            if (!t) {
                if (c.transform.length > 0)
                    continue;
                t = shift.createObject(c);
                c.transform = [t];
                _shifts.set(c, t);
            }
            c.opacity = 0;
            t.x = mode === "ink" ? -14 : 0;
            t.y = mode === "stagger" ? 10 : 0;
            entrance.createObject(root, {
                target: c,
                shift: t,
                delay: Tokens.dur(45) * i++
            });
        }
    }

    Component {
        id: shift

        Translate {}
    }

    Component {
        id: entrance

        SequentialAnimation {
            id: anim

            property Item target
            property Translate shift
            property int delay

            running: true
            onFinished: anim.destroy()

            PauseAnimation {
                duration: anim.delay
            }
            ParallelAnimation {
                NumberAnimation {
                    target: anim.target
                    property: "opacity"
                    to: 1
                    duration: Tokens.anim.normal
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: anim.shift
                    properties: "x,y"
                    to: 0
                    duration: Tokens.anim.normal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.anim.emphasizedDecel
                }
            }
        }
    }

    PanelHeader {
        id: header

        visible: root.title !== ""
        width: parent.width
        icon: root.icon
        title: root.title
        gloss: root.gloss
        subtitle: root.subtitle
    }
}
