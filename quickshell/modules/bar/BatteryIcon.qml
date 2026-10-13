import QtQuick
import qs.services
import qs.components

// A drawn battery, as on Android: a body with its tip, the charge filling it
// from the left, and the percentage inside (with the bolt while charging),
// knocked out of the charge: `hole` over the charged part, `ink` over the
// rest. The same on any bar, down or across.
Item {
    id: root

    property color ink
    property color hole
    // Kept for the Bar's wiring; the battery reads the same either way.
    property bool horizontal: false
    readonly property real level: Power.level

    implicitWidth: body.width + tip.width + 1
    implicitHeight: body.height

    StyledRect {
        id: body

        width: 30
        height: 16
        radius: 5
        color: Qt.alpha(root.ink, 0.3)

        // The label over the empty part.
        Label {
            tint: root.ink
        }

        // The charge, with the label in the hole's colour clipped to it.
        Item {
            width: Math.round(body.width * root.level)
            height: body.height
            clip: true

            Behavior on width {
                Anim {}
            }

            StyledRect {
                width: body.width
                height: body.height
                radius: body.radius
                color: root.ink
            }

            Label {
                tint: root.hole
            }
        }
    }

    StyledRect {
        id: tip

        anchors.left: body.right
        anchors.leftMargin: 1
        anchors.verticalCenter: body.verticalCenter
        width: 2
        height: 6
        radius: 1
        color: root.level >= 0.99 ? root.ink : Qt.alpha(root.ink, 0.3)
    }

    component Label: Row {
        property color tint

        x: (body.width - width) / 2
        y: (body.height - height) / 2
        spacing: 0

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: Power.charging
            text: "bolt"
            fill: 1
            size: 10
            color: parent.tint
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(root.level * 100)
            color: parent.tint
            font.pixelSize: 9
            font.weight: Font.Black
        }
    }
}
