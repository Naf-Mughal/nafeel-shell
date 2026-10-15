import QtQuick
import QtQuick.Effects

// A card as the dashboard's user card, on the shell's paper: the wallpaper
// as its cover under an ink fade from the left, anything laid over it
// (`underlay`: drawn on the cover, clipped with it: the cultivator's qi),
// at the card's rounding. Content goes on top.
Item {
    id: card

    property real sc: 1
    property bool hovered: false
    default property alias content: body.data
    property alias underlay: under.data

    // Paper, cover and what's on it, cut to the card's corners.
    Item {
        id: cover

        anchors.fill: parent
        visible: false
        layer.enabled: true

        Paper {
            anchors.fill: parent
            radius: 0
            border.width: 0
        }

        Image {
            anchors.fill: parent
            source: Xian.host?.wallpaperStill ?? ""
            sourceSize: Qt.size(Math.max(64, Math.ceil(width)), Math.max(64, Math.ceil(height)))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            opacity: 0.45
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Xian.alpha(Xian.ink, 0.88) }
                GradientStop { position: 1; color: Xian.alpha(Xian.ink, 0.25) }
            }
        }

        Item {
            id: under

            anchors.fill: parent
        }
    }

    Rectangle {
        id: corners

        anchors.fill: parent
        radius: Xian.radiusNormal
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        anchors.fill: parent
        source: cover
        maskEnabled: true
        maskSource: corners
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }

    Rectangle {
        anchors.fill: parent
        radius: Xian.radiusNormal
        color: "transparent"
        border.width: 1
        border.color: card.hovered ? Xian.alpha(Xian.gold, 0.4) : Xian.alpha(Xian.paper, 0.08)
    }

    Item {
        id: body

        anchors.fill: parent
    }
}
