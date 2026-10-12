import QtQuick
import qs.config
import qs.services

// An M3 Expressive slider: a thick filled track, a gap, the rest of the track,
// and a thin handle; an icon inside the filled part. Drag, click or scroll.
Item {
    id: root

    property real value: 0 // 0..to
    property real to: 1
    property string icon: ""
    property color fill: Colours.palette.m3primary
    property color track: Colours.palette.m3secondaryContainer
    property color ink: Colours.palette.m3onPrimary
    readonly property real fraction: Math.max(0, Math.min(1, value / to))

    signal moved(real value)

    implicitHeight: 40

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
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: filled.right
        anchors.leftMargin: 4
        width: 4
        height: parent.height + 6
        radius: 2
        color: root.fill
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
