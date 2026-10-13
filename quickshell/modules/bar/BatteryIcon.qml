import QtQuick
import qs.services
import qs.components

// A drawn battery: a faint body under its tip, the charge filling it from
// the bottom, and the percentage inside (the bolt above it while charging),
// knocked out of the charge: `hole` over the charged part, `ink` over the
// rest. The same down or across a bar.
Item {
    id: root

    property color ink
    property color hole
    // Kept for the Bar's wiring; the battery reads the same either way.
    property bool horizontal: false
    readonly property real level: Power.level

    implicitWidth: body.width
    implicitHeight: tip.height + 1 + body.height

    StyledRect {
        id: tip

        anchors.horizontalCenter: parent.horizontalCenter
        width: 7
        height: 3
        radius: 1
        color: root.level >= 0.99 ? root.ink : Qt.alpha(root.ink, 0.35)
    }

    StyledRect {
        id: body

        y: tip.height + 1
        width: 18
        height: 26
        radius: 5
        color: Qt.alpha(root.ink, 0.35)

        // The label over the empty part.
        Label {
            tint: root.ink
        }

        // The charge, from the bottom, with the label in the hole's colour
        // clipped to it.
        Item {
            id: charge

            y: body.height - height
            width: body.width
            height: Math.round(body.height * root.level)
            clip: true

            Behavior on height {
                Anim {}
            }

            StyledRect {
                y: -charge.y
                width: body.width
                height: body.height
                radius: body.radius
                color: root.ink
            }

            Label {
                y: (body.height - height) / 2 - charge.y
                tint: root.hole
            }
        }
    }

    component Label: Column {
        property color tint

        x: (body.width - width) / 2
        y: (body.height - height) / 2
        spacing: -2

        MaterialIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: Power.charging
            text: "bolt"
            fill: 1
            size: 10
            color: parent.tint
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Math.round(root.level * 100)
            color: parent.tint
            font.pixelSize: root.level >= 0.995 ? 8 : 9
            font.weight: Font.Black
        }
    }
}
