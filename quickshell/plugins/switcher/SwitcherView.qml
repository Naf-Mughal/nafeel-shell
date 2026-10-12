pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import Nafeel
import qs.config
import qs.services
import qs.components

// Alt+Tab's carousel: a live picture of each window (Switcher.list, most
// recent first), the selection centred and lifted. Only cards on screen
// capture, the selected one at full rate and the rest slowly.
// Keys: SwitcherKeys (which works before this shows).
Item {
    id: root

    readonly property int cardWidth: 320
    readonly property int thumbHeight: 180
    // Sized for its windows, within the room the frame gives it.
    property real availableWidth: 1600
    implicitWidth: Math.min(availableWidth + 2 * Tokens.barWidth - 200 - 2 * Tokens.spacing.large, Math.max(440, Switcher.list.length * cardWidth + Math.max(0, Switcher.list.length - 1) * Tokens.spacing.normal))
    implicitHeight: 36 + Tokens.spacing.normal + thumbHeight + Tokens.spacing.small + 46
    readonly property int captionHeight: 46

    Item {
        id: head

        width: parent.width
        height: 36

        GlossTitle {
            anchors.verticalCenter: parent.verticalCenter
            text: "Windows"
            gloss: Xian.gloss.windows
            size: Tokens.font.value
        }

        MicroLabel {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: `${Switcher.index + 1} of ${Switcher.list.length}`
        }
    }

    Strip {
        id: strip

        anchors.top: head.bottom
        anchors.topMargin: Tokens.spacing.normal
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width, count * root.cardWidth + Math.max(0, count - 1) * spacing)
        interactive: false
        cacheBuffer: 0
        model: Switcher.list
        currentIndex: Switcher.index
        centred: true
        wheelScrolls: false

        WheelHandler {
            orientation: Qt.Vertical
            onWheel: event => Switcher.move(event.angleDelta.y > 0 ? -1 : 1)
        }

        delegate: Item {
            id: card

            required property var modelData
            required property int index
            readonly property bool selected: ListView.isCurrentItem
            readonly property var app: Apps.forAppId(modelData.app_id)

            width: root.cardWidth
            height: strip.height
            // The selection sits forward: full size and bright; the rest
            // inset and dimmed (an inset, not a scale, keeps text crisp).
            property real inset: selected ? 0 : hover.hovered ? 3 : 6
            opacity: selected ? 1 : hover.hovered ? 0.92 : 0.72

            Behavior on opacity {
                Anim {
                    duration: Tokens.anim.fast
                }
            }
            Behavior on inset {
                Anim {
                    duration: Tokens.anim.normal
                    easing.bezierCurve: Tokens.anim.expressiveSpatial
                }
            }

            ClippingRectangle {
                id: frame

                x: card.inset
                y: card.inset
                width: parent.width - card.inset * 2
                height: root.thumbHeight - card.inset * 2
                radius: Tokens.rounding.normal
                color: Colours.palette.m3surfaceContainerLow

                // The app's icon until the first frame arrives.
                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 48
                    source: Apps.icon(card.modelData.app_id)
                    opacity: thumb.ready ? 0 : 0.8

                    Behavior on opacity {
                        Anim {
                            duration: Tokens.anim.fast
                        }
                    }
                }

                WindowThumb {
                    id: thumb

                    anchors.fill: parent
                    windowId: card.modelData.id
                    fps: card.selected ? 30 : 6
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

                // The selection: a gilded frame.
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    radius: frame.radius
                    border.width: card.selected ? 2 : 1
                    border.color: card.selected ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3onSurface, 0.13)

                    Behavior on border.color {
                        CAnim {}
                    }
                }
            }

            // The app and the window's title.
            Row {
                y: root.thumbHeight + Tokens.spacing.small
                width: parent.width
                spacing: Tokens.spacing.small

                IconImage {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 22
                    source: Apps.icon(card.modelData.app_id)
                }

                Column {
                    width: parent.width - 22 - parent.spacing

                    StyledText {
                        width: parent.width
                        text: card.app?.name ?? card.modelData.app_id
                        color: card.selected ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                        font.pixelSize: Tokens.font.body
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    StyledText {
                        width: parent.width
                        text: card.modelData.title
                        color: Colours.palette.m3onSurfaceVariant
                        font.pixelSize: Tokens.font.small
                        elide: Text.ElideRight
                    }
                }
            }

            HoverHandler {
                id: hover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                id: tap

                onTapped: {
                    Switcher.select(card.index);
                    Switcher.commit();
                }
            }
        }
    }
}
