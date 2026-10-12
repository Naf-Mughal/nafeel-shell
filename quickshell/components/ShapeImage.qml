import QtQuick
import QtQuick.Effects
import M3Shapes
import qs.config
import qs.services

// An image cut to a Material 3 shape (cover art in a cookie, a face in a
// pill), with a fallback icon on the shape's fill while there's no picture.
// `shapeItem` is the MaterialShape (its distanceAtAngle() lets a visualiser
// start on the edge).
//
//   ShapeImage { source: art; shape: MaterialShape.Cookie9Sided; icon: "music_note" }
Item {
    id: root

    property alias source: img.source
    property alias shape: mask.shape
    property alias shapeItem: mask
    property string icon: "image"
    property color fill: Colours.roleFill("paper", "soft", 4)
    readonly property bool ready: img.status === Image.Ready

    MaterialShape {
        id: mask

        anchors.fill: parent
        color: root.fill
        // The mask's alpha only matters, but it also is the fallback.
        layer.enabled: true
    }

    MaterialIcon {
        visible: !root.ready
        anchors.centerIn: parent
        text: root.icon
        size: Math.min(root.width, root.height) * 0.36
        color: Colours.roleInk("paper", "soft")
    }

    Image {
        id: img

        anchors.fill: parent
        visible: false
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
    }

    MultiEffect {
        anchors.fill: parent
        visible: root.ready
        source: img
        maskEnabled: true
        maskSource: mask
        maskSpreadAtMin: 1
        maskThresholdMin: 0.5
    }
}
