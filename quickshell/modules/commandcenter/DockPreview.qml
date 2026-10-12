pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import Nafeel
import qs.config
import qs.services
import qs.components

// Live previews of one dock app's windows, grown out of the dock as part of
// its panel (the drawer takes their height): each a picture of the window
// (WindowThumb, as Alt+Tab draws them) with its title; a click goes to it.
Row {
    id: root

    property var item: null
    readonly property int thumbHeight: Dock.settings.v["dock.previewHeight"]
    readonly property int cardWidth: Math.round(thumbHeight * 1.6)

    spacing: Tokens.spacing.normal

    Repeater {
        model: root.item?.windows ?? []

        Item {
            id: card

            required property var modelData

            width: root.cardWidth
            height: root.thumbHeight + Tokens.spacing.small + title.implicitHeight

            ClippingRectangle {
                id: frame

                width: parent.width
                height: root.thumbHeight
                radius: Tokens.rounding.normal
                color: Colours.palette.m3surfaceContainerLow
                border.width: card.modelData.focused ? 2 : 0
                border.color: Colours.palette.m3primary

                AppIcon {
                    anchors.centerIn: parent
                    size: 48
                    appId: card.modelData.app_id
                    opacity: thumb.ready ? 0 : 0.8
                }

                WindowThumb {
                    id: thumb

                    anchors.fill: parent
                    windowId: card.modelData.id
                    crop: true
                    fps: hover.hovered ? 30 : 8
                    opacity: ready ? 1 : 0

                    Behavior on opacity {
                        Anim {
                            duration: Tokens.anim.normal
                        }
                    }
                }

                StateLayer {
                    hovered: hover.hovered
                    pressed: tap.pressed
                    ink: Colours.palette.m3onSurface
                }
            }

            StyledText {
                id: title

                anchors.top: frame.bottom
                anchors.topMargin: Tokens.spacing.small
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: card.modelData.title || card.modelData.app_id
                color: card.modelData.focused ? Colours.palette.m3primary : Colours.palette.m3onSurface
                font.pixelSize: Tokens.font.small
                elide: Text.ElideRight
            }

            HoverHandler {
                id: hover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                id: tap

                onTapped: {
                    Umbriel.dispatch("window-focus:" + card.modelData.id);
                    ShellState.dockPreview = "";
                }
            }
        }
    }
}
