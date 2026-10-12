import QtQuick
import qs.services
import qs.components

// A drawn battery: a faint body, the charge filling it from the bottom, the
// charging bolt in whichever part has more room, and the percentage below.
Column {
    id: root

    property color ink
    property color hole
    readonly property real level: Power.level
    readonly property int bodyHeight: 24

    spacing: 2

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 1

        StyledRect {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 7
            height: 3
            radius: 1
            color: Qt.alpha(root.ink, 0.35)
        }

        StyledRect {
            id: body

            width: 16
            height: root.bodyHeight
            radius: 5
            color: Qt.alpha(root.ink, 0.35)

            StyledRect {
                anchors.bottom: parent.bottom
                width: parent.width
                height: Math.round(root.bodyHeight * root.level)
                radius: 5
                color: root.ink

                Behavior on height {
                    Anim {}
                }
            }

            MaterialIcon {
                visible: Power.charging
                anchors.horizontalCenter: parent.horizontalCenter
                // In the empty part when there's more of it, else in the charge.
                y: root.level < 0.5 ? (parent.height * (1 - root.level) - height) / 2 : parent.height * (1 - root.level) + (parent.height * root.level - height) / 2
                text: "bolt"
                fill: 1
                size: 12
                color: root.level < 0.5 ? root.ink : root.hole
            }
        }
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Math.round(root.level * 100)
        color: root.ink
        font.pixelSize: 11
        font.weight: Font.Bold
    }
}
