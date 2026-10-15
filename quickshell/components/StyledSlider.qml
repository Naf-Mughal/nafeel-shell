import QtQuick
import qs.config
import qs.services
import "keynav.js" as KeyNav

// An M3 Expressive slider: a thick filled track, a gap, the rest of the track,
// and a thin handle; an icon inside the filled part. Drag, click or scroll.
// Held, the handle swells and a bubble above it shows the value, rolling.
Item {
    id: root

    property real value: 0 // 0..to
    property real to: 1
    property string icon: ""
    property color fill: Colours.palette.m3primary
    property color track: Colours.palette.m3secondaryContainer
    property color ink: Colours.palette.m3onPrimary
    readonly property real fraction: Math.max(0, Math.min(1, value / to))
    // What the bubble says while it's dragged (a percentage by default).
    property string valueText: Math.round(fraction * 100) + "%"
    // Held: the handle swells and the bubble shows the value.
    readonly property bool grabbed: drag.active || tap.pressed

    signal moved(real value)

    implicitHeight: 40

    // The keyboard: Left / Right step it by a twentieth (Page keys by a
    // fifth, Home / End to the ends); Up / Down and Tab move on (keynav.js).
    property bool focusByKey: false
    activeFocusOnTab: true
    onActiveFocusChanged: {
        if (!activeFocus)
            focusByKey = false;
    }
    Keys.onPressed: event => {
        const k = event.key;
        if (k === Qt.Key_Left || k === Qt.Key_Right || k === Qt.Key_PageUp || k === Qt.Key_PageDown) {
            const step = (k === Qt.Key_PageUp || k === Qt.Key_PageDown ? 0.2 : 0.05) * to;
            const up = k === Qt.Key_Right || k === Qt.Key_PageUp;
            moved(Math.max(0, Math.min(to, value + (up ? step : -step))));
        } else if (k === Qt.Key_Home || k === Qt.Key_End) {
            moved(k === Qt.Key_End ? to : 0);
        } else if (k === Qt.Key_Down || k === Qt.Key_Tab) {
            KeyNav.move(root, true);
        } else if (k === Qt.Key_Up || k === Qt.Key_Backtab) {
            KeyNav.move(root, false);
        } else {
            return;
        }
        event.accepted = true;
    }

    // The ring while the keyboard is on it.
    StyledRect {
        anchors.fill: parent
        anchors.margins: -3
        visible: root.activeFocus && root.focusByKey
        color: "transparent"
        radius: Tokens.rounding.small + 3
        border.width: 2
        border.color: Colours.palette.m3primary
    }

    function setFromX(x: real): void {
        moved(Math.max(0, Math.min(1, x / width)) * to);
    }

    StyledRect {
        id: filled

        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(height, (root.width - 10) * root.fraction)
        height: parent.height
        radius: Tokens.rounding.small
        color: root.fill

        Behavior on width {
            enabled: !drag.active
            Anim {
                duration: Tokens.anim.fast
            }
        }

        MaterialIcon {
            visible: root.icon !== ""
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            fill: 1
            color: root.ink
            size: 20
        }
    }

    StyledRect {
        id: handle

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: filled.right
        anchors.leftMargin: root.grabbed ? 3 : 4
        width: root.grabbed ? 6 : 4
        height: parent.height + (root.grabbed ? 12 : 6)
        radius: width / 2
        color: root.fill

        Behavior on width {
            Anim {
                duration: Tokens.anim.fast
                easing.bezierCurve: Tokens.anim.expressiveFastSpatial
            }
        }
        Behavior on height {
            Anim {
                duration: Tokens.anim.fast
                easing.bezierCurve: Tokens.anim.expressiveFastSpatial
            }
        }
    }

    // The value while it's held, in a bubble over the handle.
    StyledRect {
        id: bubble

        anchors.horizontalCenter: handle.horizontalCenter
        anchors.bottom: handle.top
        anchors.bottomMargin: 6
        width: readout.implicitWidth + 16
        height: 26
        radius: Math.min(height / 2, Tokens.rounding.morph)
        color: Colours.palette.m3inverseSurface
        opacity: root.grabbed ? 1 : 0
        scale: root.grabbed ? 1 : 0.6
        transformOrigin: Item.Bottom
        visible: opacity > 0.01

        Behavior on opacity {
            Anim {
                duration: Tokens.anim.fast
            }
        }
        Behavior on scale {
            Anim {
                duration: Tokens.anim.fast
                easing.bezierCurve: Tokens.anim.expressiveFastSpatial
            }
        }

        RollText {
            id: readout

            anchors.centerIn: parent
            text: root.valueText
            color: Colours.palette.m3inverseOnSurface
            font.pixelSize: Tokens.font.small
            font.weight: Font.DemiBold
        }
    }

    StyledRect {
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        width: Math.max(0, root.width - filled.width - 12)
        height: parent.height
        radius: Tokens.rounding.small
        color: root.track
    }

    DragHandler {
        id: drag

        target: null
        xAxis.enabled: true
        yAxis.enabled: false
        onCentroidChanged: if (active)
            root.setFromX(centroid.position.x)
    }

    TapHandler {
        id: tap

        onTapped: point => root.setFromX(point.position.x)
    }

    // Only a sideways scroll moves it: the vertical wheel scrolls the panel
    // it's in.
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        orientation: Qt.Horizontal
        onWheel: event => {
            if (event.angleDelta.x !== 0)
                root.moved(Math.max(0, Math.min(root.to, root.value + (event.angleDelta.x > 0 ? 0.05 : -0.05))));
        }
    }
}
