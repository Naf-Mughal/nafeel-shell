pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// One bar control: an icon (or custom content) inside a BarGroup. Resting
// the pointer on it previews its popout, a click pins/unpins it (or runs
// `clicked` when it has none), right-click is the quick action, scrolling is
// `scrolled`. No tooltips: the details live in the popout.
Item {
    id: root

    property ShellScreen shellScreen
    // The bar popout this opens ("network", "audio", …), or "".
    property string popout: ""
    // Or another drawer it opens instead (the session corner).
    property string target: ""
    property string icon: ""
    property real iconFill: active ? 1 : 0
    // A warning colour that wins over the group's ink (low battery, muted).
    property color alert: "transparent"
    property bool dot: false

    // Set by the BarGroup.
    property color groupInk
    property color groupActiveInk

    readonly property string key: target || (popout ? `bar:${popout}` : "")
    readonly property string screenName: shellScreen?.name ?? ""
    readonly property bool hovered: hover.hovered
    readonly property bool active: hovered || (key !== "" && ShellState.current(screenName) === key && ShellState.barHover === "")
    readonly property color ink: alert.a > 0 ? alert : active ? groupActiveInk : groupInk

    default property alias content: holder.data

    signal clicked
    signal rightClicked
    signal middleClicked
    signal scrolled(bool up)

    function openPopout(pin: bool): void {
        ShellState.anchorTo(key);
        if (pin)
            ShellState.pin(key, screenName);
        else
            ShellState.preview(key, screenName);
    }

    Component.onCompleted: {
        if (key) {
            ShellState.barControls[key] = root;
        }
    }

    width: parent?.width ?? 28
    readonly property bool hasContent: holder.visibleChildren.length > 0

    implicitHeight: Math.max(30, hasContent ? holder.childrenRect.height + 12 : 0)

    MaterialIcon {
        anchors.centerIn: parent
        visible: root.icon !== "" && !root.hasContent
        text: root.icon
        fill: root.iconFill
        color: root.ink
        size: 20
    }

    Item {
        id: holder

        anchors.centerIn: parent
        width: childrenRect.width
        height: childrenRect.height
    }

    StyledRect {
        visible: root.dot
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 5
        width: 7
        height: 7
        radius: 4
        color: Colours.palette.m3error
    }

    // Hover delay before the preview, so sweeping across the bar doesn't
    // flash every popout.
    Timer {
        id: hoverDelay

        interval: 140
        onTriggered: root.openPopout(false)
    }

    HoverHandler {
        id: hover

        onHoveredChanged: {
            if (hovered) {
                ShellState.barHover = root.key || "icon";
                if (root.key)
                    hoverDelay.restart();
            } else {
                if (ShellState.barHover === (root.key || "icon"))
                    ShellState.barHover = "";
                hoverDelay.stop();
                if (root.key)
                    ShellState.unpreviewLater(root.key);
            }
        }
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: {
            if (!root.key) {
                root.clicked();
            } else if (ShellState.pinned === root.key) {
                ShellState.close();
            } else {
                hoverDelay.stop();
                root.openPopout(true);
            }
        }
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: root.rightClicked()
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton
        onTapped: root.middleClicked()
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => root.scrolled(event.angleDelta.y > 0)
    }
}
