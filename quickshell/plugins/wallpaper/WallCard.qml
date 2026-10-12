import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// One wallpaper, as every picker view shows it: the library's thumbnail (the
// file itself until the index has one), the current one in gold with its
// seal 印, the chosen one (set when the picker closes) in wet ink with 選, the
// keyboard's selection as an ink frame, a favourite's star, and its colours
// as a row of pigment dots along the foot when it's selected.
Item {
    id: root

    required property var wall
    property bool selected: false
    property real radius: Tokens.rounding.normal
    // Show the colour dots and the favourite toggle (not in tiny cells).
    property bool details: true

    readonly property bool current: (wall.path ?? "") !== "" && wall.path === Wallpapers.wallpaperOf(Wallpapers.target)
    readonly property bool chosen: wall.path !== "" && wall.path === Wallpapers.chosen
    readonly property bool favourite: Wallpapers.favourites[wall.path] ?? false
    readonly property bool hovered: hover.hovered

    signal tapped
    signal doubleTapped

    ClippingRectangle {
        id: thumb

        anchors.fill: parent
        anchors.margins: root.current || root.selected || root.chosen ? 0 : root.hovered ? 2 : 4
        radius: root.radius
        color: Colours.palette.m3surfaceContainerHigh

        Behavior on anchors.margins {
            Anim {
                duration: Tokens.anim.fast
            }
        }

        Image {
            anchors.fill: parent
            source: Wallpapers.picture(root.wall)
            sourceSize: Qt.size(Math.round(root.width * 1.2), Math.round(root.height * 1.2))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            opacity: status === Image.Ready ? 1 : 0

            Behavior on opacity {
                Anim {
                    duration: Tokens.anim.normal
                }
            }
        }

        // The pigments, along the foot of the selected one.
        Row {
            visible: root.details && (root.selected || root.hovered) && (root.wall.colours?.length ?? 0) > 0
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: Tokens.spacing.small
            spacing: 3

            Repeater {
                model: root.wall.colours ?? []

                Rectangle {
                    required property string modelData

                    width: 10
                    height: 10
                    radius: 5
                    color: modelData
                    border.width: 1
                    border.color: Qt.alpha(Colours.palette.m3shadow, 0.5)
                }
            }
        }

        // A live wallpaper moves while it's the selected one.
        Loader {
            anchors.fill: parent
            active: (root.wall.video ?? false) && !!root.wall.preview && (root.selected || root.hovered)
            sourceComponent: AnimatedImage {
                source: "file://" + root.wall.preview
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                playing: true
            }
        }

        // A live wallpaper.
        MaterialIcon {
            visible: root.wall.video ?? false
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Tokens.spacing.small
            text: "play_circle"
            fill: 1
            size: 20
            color: "white"
            style: Text.Outline
            styleColor: Qt.alpha("black", 0.5)
        }

        StoreBadge {
            anchors.fill: parent
            wall: root.wall
        }

        Rectangle {
            anchors.fill: parent
            visible: root.chosen
            color: "transparent"
            radius: thumb.radius
            border.width: 3
            border.color: Colours.palette.m3tertiary
        }

        Rectangle {
            anchors.fill: parent
            visible: root.selected && !root.current && !root.chosen
            color: "transparent"
            radius: thumb.radius
            border.width: 2
            border.color: Colours.palette.m3onSurface
        }

        Rectangle {
            anchors.fill: parent
            visible: root.current
            color: "transparent"
            radius: thumb.radius
            border.width: 2
            border.color: Colours.palette.m3primary
        }

        Seal {
            visible: root.chosen
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Tokens.spacing.small
            glyph: "選"
            size: 20
        }

        Seal {
            visible: root.current
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Tokens.spacing.small
            glyph: "印"
            size: 20
        }

        // Favourite: shown when it is one, or on hover to make it one.
        MaterialIcon {
            visible: root.details && (root.favourite || root.hovered)
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.spacing.small
            text: "star"
            fill: root.favourite ? 1 : 0
            size: 18
            color: root.favourite ? Colours.palette.m3primary : "white"
            style: Text.Outline
            styleColor: Qt.alpha("black", 0.5)

            TapHandler {
                onTapped: Wallpapers.toggleFavourite(root.wall.path)
            }
        }
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: root.tapped()
        onDoubleTapped: root.doubleTapped()
    }
}
