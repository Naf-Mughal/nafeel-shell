pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import M3Shapes
import qs.config
import qs.services
import qs.components

// A processor: its load as a ring round its icon, name, temperature on a
// bar, and the load again large inside a shape (calm cookie, then sunny,
// then a burst as it climbs), as Caelestia's hero card.
Surface {
    id: hero

    property string icon
    property string label
    property string subLabel
    property real usage
    property real temperature
    property string role: "primary"
    readonly property color accent: Colours.roleInk(role, "ghost")

    level: 2
    shape: "large"

    CircularProgress {
        id: ring

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Tokens.spacing.normal
        implicitSize: 48
        strokeWidth: 4
        gap: 4
        value: hero.usage
        fg: hero.accent

        MaterialIcon {
            anchors.centerIn: parent
            text: hero.icon
            size: 24
            color: hero.accent
        }
    }

    Column {
        anchors.left: ring.right
        anchors.leftMargin: Tokens.spacing.normal
        anchors.right: usageShape.left
        anchors.rightMargin: Tokens.spacing.normal
        anchors.verticalCenter: ring.verticalCenter
        spacing: 2

        StyledText {
            text: hero.label
            color: hero.accent
            font.pixelSize: Tokens.font.title
        }

        StyledText {
            width: parent.width
            text: hero.subLabel
            color: hero.subInk
            font.pixelSize: Tokens.font.small
            elide: Text.ElideRight
        }
    }

    Column {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.spacing.normal
        spacing: 6

        Row {
            spacing: 4

            MaterialIcon {
                text: hero.temperature > 90 ? "thermometer_alert" : "thermometer"
                fill: 1
                size: 20
                color: hero.temperature > 90 ? Colours.roleInk("error", "ghost") : hero.accent
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: `${Math.round(hero.temperature)}°C`
                color: hero.ink
                font.pixelSize: Tokens.font.row
            }
        }

        LinearProgress {
            width: 150
            value: hero.temperature / 100
            fg: hero.accent
        }
    }

    StyledText {
        anchors.bottom: usageShape.top
        anchors.horizontalCenter: usageShape.horizontalCenter
        text: "Usage"
        color: hero.subInk
        font.pixelSize: Tokens.font.small
    }

    MaterialShape {
        id: usageShape

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.spacing.normal
        implicitSize: 78
        color: Colours.roleFill("secondary", "soft", 0)
        shape: hero.usage >= 0.8 ? MaterialShape.SoftBurst : hero.usage >= 0.4 ? MaterialShape.Sunny : MaterialShape.Cookie4Sided

        StyledText {
            anchors.centerIn: parent
            text: `${Math.round(hero.usage * 100)}%`
            color: hero.accent
            font.pixelSize: 26
            font.weight: Font.DemiBold
        }
    }
}
