pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import M3Shapes
import qs.config
import qs.services
import qs.components

Item {
    id: tc

    property color accent
    property color ink
    property color subInk

    MaterialIcon {
        anchors.left: parent.left
        anchors.top: parent.top
        text: "battery_full"
        size: 30
        fill: 1
        color: tc.accent
    }

    StyledText {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.topMargin: 36
        text: "Battery"
        color: tc.ink
        font.pixelSize: Tokens.font.row
    }

    Column {
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        StyledText {
            anchors.right: parent.right
            text: Power.charging ? "Charging" : Power.timeToEmpty > 0 ? `${Math.floor(Power.timeToEmpty / 3600)}h ${Math.floor(Power.timeToEmpty % 3600 / 60)}m` : "…"
            color: tc.subInk
            font.pixelSize: Tokens.font.small
        }

        Row {
            anchors.right: parent.right
            spacing: 2

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                visible: Power.charging
                text: "bolt"
                fill: 1
                size: 26
                color: tc.accent
            }

            StyledText {
                text: `${Math.round(Power.level * 100)}%`
                color: tc.accent
                font.pixelSize: 34
                font.weight: Font.DemiBold
            }
        }
    }
}
