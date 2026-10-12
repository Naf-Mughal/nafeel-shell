import QtQuick
import qs.config
import qs.services

// The wheel for a scrolling view (Scroller, Strip): each notch moves `step`
// pixels (the Panels page's scroll step) with a short glide, and quick
// notches add up; a touchpad moves exactly as far as the fingers. A sideways
// view reads the wheel sideways too.
WheelHandler {
    id: root

    required property Flickable view
    property bool horizontal: false
    property real step: ShellState.settings.v["panels.scrollStep"]
    // Where a glide is heading.
    property real goal: 0

    readonly property real lowest: horizontal ? view.originX : view.originY
    readonly property real highest: lowest + Math.max(0, horizontal ? view.contentWidth - view.width : view.contentHeight - view.height)

    function clamped(v: real): real {
        return Math.max(lowest, Math.min(highest, v));
    }

    property NumberAnimation glide: NumberAnimation {
        target: root.view
        property: root.horizontal ? "contentX" : "contentY"
        duration: Tokens.anim.fast
        easing.type: Easing.OutCubic
    }

    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: event => {
        const now = root.horizontal ? root.view.contentX : root.view.contentY;
        const fingers = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.pixelDelta.x;
        if (fingers !== 0) {
            root.glide.stop();
            root.view[root.horizontal ? "contentX" : "contentY"] = root.clamped(now - fingers);
            return;
        }
        const notches = (event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x) / 120;
        root.goal = root.clamped((root.glide.running ? root.goal : now) - notches * root.step);
        root.glide.to = root.goal;
        root.glide.restart();
    }
}
