pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// What the lock shows of the running session, on the shell's primitives
// (the lock's host hands it to the surface; the login screen has none):
// what's playing on a card, bottom left; the capture buttons beside the
// session ones; the OSD out of the top as it is on the desktop; the
// notifications' toasts, top right.
Item {
    id: root

    property real sc: 1
    property real edge: 60
    property var ctx: null

    // ── What's playing ──
    Surface {
        id: player

        x: root.edge
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 44 * root.sc
        visible: Media.active !== null
        level: 2
        width: 340 * root.sc
        height: 100 * root.sc

        Row {
            anchors.fill: parent
            anchors.margins: Tokens.spacing.normal
            spacing: Tokens.spacing.normal

            ShapeImage {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.height
                height: parent.height
                source: Media.art
                icon: "music_note"
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - parent.height - Tokens.spacing.normal
                spacing: 2

                StyledText {
                    width: parent.width
                    elide: Text.ElideRight
                    text: Media.title || Media.active?.identity || ""
                    font.family: Tokens.font.serif
                    font.pixelSize: Tokens.font.body
                }

                MicroLabel {
                    width: parent.width
                    elide: Text.ElideRight
                    text: Media.artist || (Media.playing ? "Playing" : "Paused")
                }

                Row {
                    spacing: Tokens.spacing.small
                    topPadding: 4

                    IconButton {
                        icon: "skip_previous"
                        size: 32
                        onClicked: {
                            root.ctx?.poke();
                            Media.previous();
                        }
                    }
                    IconButton {
                        icon: Media.playing ? "pause" : "play_arrow"
                        size: 32
                        filled: true
                        onClicked: {
                            root.ctx?.poke();
                            Media.playPause();
                        }
                    }
                    IconButton {
                        icon: "skip_next"
                        size: 32
                        onClicked: {
                            root.ctx?.poke();
                            Media.next();
                        }
                    }
                }
            }
        }
    }

    // ── Capture, left of the session's buttons ──
    Row {
        anchors.right: parent.right
        // The session's three (50 each, 14 apart) and a gap.
        anchors.rightMargin: root.edge + (3 * 50 + 2 * 14 + 28) * root.sc
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 44 * root.sc
        spacing: 14 * root.sc
        visible: CaveAbode.captureAvailable

        Repeater {
            model: [
                {
                    zh: "影",
                    en: "Capture",
                    event: "screenshot"
                },
                {
                    zh: "录",
                    en: "Record",
                    event: "record"
                }
            ]

            Column {
                id: cap

                required property var modelData
                readonly property bool live: modelData.event === "record" && CaveAbode.recording
                spacing: 6 * root.sc

                Surface {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 50 * root.sc
                    height: width
                    level: 2
                    role: cap.live ? "error" : "paper"
                    interactive: true
                    onClicked: {
                        root.ctx?.poke();
                        CaveAbode.captureCommand(cap.modelData.event);
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: cap.live ? "停" : cap.modelData.zh
                        color: parent.ink
                        font.family: Tokens.font.cjk
                        font.weight: Font.Black
                        font.pixelSize: 20 * root.sc
                    }
                }

                MicroLabel {
                    anchors.horizontalCenter: parent.horizontalCenter
                    readonly property int secs: CaveAbode.recordedSeconds(root.ctx?.now ?? new Date())
                    text: cap.live ? Math.floor(secs / 60) + ":" + String(secs % 60).padStart(2, "0") : cap.modelData.en
                }
            }
        }
    }

    // ── The OSD, out of the top ──
    Surface {
        readonly property var osd: Plugins.instance("osd")

        anchors.horizontalCenter: parent.horizontalCenter
        y: osd?.shown ? 24 * root.sc : -height - 10
        visible: osdView.status === Loader.Ready && y > -height
        level: 2
        width: osdView.item?.implicitWidth ?? 0
        height: osdView.item?.implicitHeight ?? 0

        Behavior on y {
            Anim {}
        }

        Loader {
            id: osdView

            anchors.fill: parent
            active: Plugins.isEnabled("osd")
            source: Qt.resolvedUrl("../osd/OsdView.qml")
        }
    }

    // ── Notifications, top right (under the hour) ──
    Loader {
        anchors.right: parent.right
        anchors.rightMargin: root.edge
        y: 200 * root.sc
        width: 400
        active: Plugins.isEnabled("notifications")
        source: Qt.resolvedUrl("../notifications/Toasts.qml")
    }
}
