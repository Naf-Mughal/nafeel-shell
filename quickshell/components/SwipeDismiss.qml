import QtQuick
import qs.config
import qs.services

// Swipe sideways to dismiss, for the item it's in (a notification, a
// toast): the item follows the finger 1:1 at first and then with growing
// resistance, like pulling on something elastic (M3 Expressive); past
// `commit` of its width, or flung, it flies off fading and `dismissed`
// fires; let go short and it springs back. The item applies it:
//   transform: Translate { x: swipe.shift }   (and its ink fading by swipe.fade)
//   SwipeDismiss { id: swipe; onDismissed: … }
Item {
    id: root

    // How far (a fraction of the width) a release must be to dismiss.
    property real commit: 0.4
    property bool toLeft: true
    property bool toRight: true
    signal dismissed

    // Where the finger has pulled it (raw), where it shows (resisted).
    property real pull: 0
    readonly property real span: Math.max(1, width)
    readonly property real resisted: span * 0.75 * Math.tanh(pull / (span * 0.75))
    property real flown: 0
    property bool leaving: false
    readonly property bool dragging: drag.active
    readonly property real shift: leaving ? flown : resisted
    readonly property real fade: 1 - Math.min(1, Math.abs(shift) / span) * 0.9

    anchors.fill: parent

    DragHandler {
        id: drag

        enabled: root.enabled && !root.leaving
        target: null
        yAxis.enabled: false

        onTranslationChanged: {
            if (!active)
                return;
            let dx = translation.x;
            if (!root.toLeft)
                dx = Math.max(0, dx);
            if (!root.toRight)
                dx = Math.min(0, dx);
            back.stop();
            root.pull = dx;
        }
        onActiveChanged: {
            if (active)
                return;
            const v = centroid.velocity.x;
            const fling = Math.abs(v) > 900 && Math.sign(v) === Math.sign(root.pull);
            if (Math.abs(root.resisted) > root.span * root.commit || fling)
                root.fly(root.pull >= 0 ? 1 : -1);
            else
                back.restart();
        }
    }

    function fly(dir: int): void {
        flown = resisted;
        leaving = true;
        away.to = dir * span * 1.15;
        away.restart();
    }

    // Short of it: springs back.
    SpringAnimation {
        id: back

        target: root
        property: "pull"
        to: 0
        spring: Tokens.spring.control.spring
        damping: Tokens.spring.control.damping
        epsilon: 0.5
    }

    // Past it: flies off, then it's gone.
    NumberAnimation {
        id: away

        target: root
        property: "flown"
        duration: Tokens.anim.fast
        easing.type: Easing.InCubic
        onFinished: root.dismissed()
    }
}
