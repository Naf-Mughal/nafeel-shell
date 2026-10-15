pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// Which player the media tab shows (Spotify, Chrome, mpv…): a full-width
// selector with the one showing; it opens a list above itself to choose
// another (Media.choose).
Item {
    id: root

    property bool open: false

    implicitHeight: 52
    enabled: Media.players.length > 0

    function name(p: var): string {
        return p ? (p.identity || p.desktopEntry || "Player") : "No players";
    }

    Surface {
        id: button

        anchors.fill: parent
        role: "secondary"
        emphasis: "soft"
        interactive: Media.players.length > 1
        onClicked: root.open = !root.open

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Tokens.spacing.normal
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.spacing.small

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: Media.playing ? "graphic_eq" : Media.players.length ? "music_note" : "music_off"
                size: 20
                color: button.ink
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.name(Media.active)
                color: button.ink
                font.pixelSize: Tokens.font.row
            }
        }

        MaterialIcon {
            visible: Media.players.length > 1
            anchors.right: parent.right
            anchors.rightMargin: Tokens.spacing.normal
            anchors.verticalCenter: parent.verticalCenter
            text: root.open ? "expand_more" : "expand_less"
            size: 20
            color: button.ink
        }
    }

    // The list, above.
    Surface {
        visible: root.open
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: button.top
        anchors.bottomMargin: 4
        height: list.implicitHeight + 8
        level: 4
        z: 10

        // The goo on the player in use, following the hover.
        ListGoo {
            id: playersGoo

            anchors.fill: list
            container: list
        }

        Column {
            id: list

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 4
            spacing: 2

            Repeater {
                // Diffed (ScriptModel): a new array (a signal strength, a stream
                // coming or going) moves or adds rows; rebuilding every row held the GUI
                // thread past a refresh, dropping a frame of whatever was animating.
                model: ScriptModel {
                    values: Media.players
                }
                Surface {
                    id: item

                    required property var modelData
                    readonly property bool on: modelData === Media.active
                    // A goo row (the list's goo rests on the one in use).
                    property Item goo: playersGoo
                    readonly property bool picked: on
                    readonly property bool inked: playersGoo.covers(item)

                    width: list.width
                    height: 38
                    emphasis: "ghost"
                    hoverLayer: false
                    baseInk: inked ? Colours.roleInk("secondary", "soft") : Colours.roleInk("paper", "soft")
                    baseSubInk: inked ? Colours.roleSubInk("secondary", "soft") : Colours.roleSubInk("paper", "soft")
                    interactive: true
                    onClicked: {
                        Media.choose(item.modelData);
                        root.open = false;
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Tokens.spacing.normal
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: item.on ? "check" : item.modelData.isPlaying ? "graphic_eq" : "music_note"
                            size: 18
                            color: item.ink
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.name(item.modelData)
                            color: item.ink
                            font.pixelSize: Tokens.font.body
                        }
                    }
                }
            }
        }
    }
}
