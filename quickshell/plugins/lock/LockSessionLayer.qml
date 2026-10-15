pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
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

    // ── What's playing: a card as the cultivator's beside it ──
    // The cover as the card's cover under an ink fade, the art itself, title
    // and artist, the controls, and how far in along the bottom.
    Surface {
        id: player

        readonly property var mp: Media.active
        readonly property real length: mp?.length ?? 0

        x: root.edge
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 44 * root.sc
        visible: mp !== null
        level: 2
        width: 420 * root.sc
        height: 100 * root.sc
        // The panels' paper (fibre and wash), not a flat fill.
        fill: "transparent"

        // MPRIS only updates the position when asked.
        Timer {
            running: player.visible && Media.playing
            interval: 1000
            repeat: true
            triggeredOnStart: true
            onTriggered: player.mp?.positionChanged()
        }

        PaperSheet {
            anchors.fill: parent
            radius: player.restRadius
        }

        ClippingRectangle {
            anchors.fill: parent
            radius: player.restRadius
            color: "transparent"

            Image {
                anchors.fill: parent
                source: Media.art
                sourceSize: Qt.size(Math.max(64, Math.ceil(width)), Math.max(64, Math.ceil(height)))
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: 0.4
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: Qt.alpha(Colours.palette.m3surface, 0.92)
                    }
                    GradientStop {
                        position: 1
                        color: Qt.alpha(Colours.palette.m3surface, 0.3)
                    }
                }
            }

            // How far in.
            Rectangle {
                anchors.bottom: parent.bottom
                height: 2
                width: parent.width * (player.length > 0 ? Math.min(1, (player.mp?.position ?? 0) / player.length) : 0)
                color: Colours.palette.m3primary
                opacity: 0.8
            }
        }

        // The art, a square at a card's rounding.
        ClippingRectangle {
            id: art

            anchors.left: parent.left
            anchors.leftMargin: 18 * root.sc
            anchors.verticalCenter: parent.verticalCenter
            width: 62 * root.sc
            height: width
            radius: Tokens.rounding.normal
            color: Colours.roleFill("paper", "soft", 4)

            MaterialIcon {
                anchors.centerIn: parent
                visible: artImg.status !== Image.Ready
                text: "music_note"
                size: 26
                color: Colours.palette.m3onSurfaceVariant
            }

            Image {
                id: artImg

                anchors.fill: parent
                source: Media.art
                sourceSize: Qt.size(128, 128)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }

        Column {
            anchors.left: art.right
            anchors.leftMargin: 16 * root.sc
            anchors.right: controls.left
            anchors.rightMargin: 12 * root.sc
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            StyledText {
                width: parent.width
                elide: Text.ElideRight
                text: Media.title || player.mp?.identity || ""
                font.family: Tokens.font.serif
                font.pixelSize: 18 * root.sc
            }

            MicroLabel {
                width: parent.width
                elide: Text.ElideRight
                text: Media.artist || (Media.playing ? "Playing" : "Paused")
            }
        }

        Row {
            id: controls

            anchors.right: parent.right
            anchors.rightMargin: 16 * root.sc
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.spacing.small

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "skip_previous"
                size: 34
                onClicked: {
                    root.ctx?.poke();
                    Media.previous();
                }
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: Media.playing ? "pause" : "play_arrow"
                size: 42
                filled: true
                onClicked: {
                    root.ctx?.poke();
                    Media.playPause();
                }
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "skip_next"
                size: 34
                onClicked: {
                    root.ctx?.poke();
                    Media.next();
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
                        if (cap.live)
                            CaveAbode.captureCommand("record");
                        else
                            root.pick(cap.modelData.event);
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

    // ── Picking a region to capture (the lock's own: nothing else can
    // draw over it): drag one out; a click without dragging takes the whole
    // screen; Esc or a right-click lets it go. ──
    property string picking: ""
    property Item _focusWas: null

    function pick(event: string): void {
        _focusWas = Window.window?.activeFocusItem ?? null;
        picking = event;
        picker.forceActiveFocus();
    }

    function _endPick(): void {
        picking = "";
        _focusWas?.forceActiveFocus();
    }

    function _take(event: string, area: var): void {
        _endPick();
        // Once the picker is off the screen.
        takeLater.event = event;
        takeLater.area = area;
        takeLater.restart();
    }

    Timer {
        id: takeLater

        property string event
        property var area
        interval: 120
        onTriggered: Plugins.instance("capture")?.capture?.lockedCapture(event, Window.window?.screen?.name ?? "", area)
    }

    Item {
        id: picker

        anchors.fill: parent
        visible: root.picking !== ""
        z: 10
        focus: visible
        Keys.onEscapePressed: root._endPick()

        readonly property real x0: Math.min(drag.ax, drag.bx)
        readonly property real y0: Math.min(drag.ay, drag.by)
        readonly property real w: Math.abs(drag.bx - drag.ax)
        readonly property real h: Math.abs(drag.by - drag.ay)

        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(Colours.palette.m3scrim, 0.35)
        }

        Rectangle {
            visible: drag.pressed
            x: picker.x0
            y: picker.y0
            width: picker.w
            height: picker.h
            color: Qt.alpha(Colours.palette.m3primary, 0.08)
            border.width: 1.5
            border.color: Colours.palette.m3primary
            radius: Tokens.rounding.small
        }

        Surface {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 28 * root.sc
            level: 2
            width: hint.implicitWidth + Tokens.spacing.large * 2
            height: 36

            StyledText {
                id: hint

                anchors.centerIn: parent
                text: (root.picking === "record" ? "Record" : "Capture") + " a region: drag it out · click for the whole screen · Esc to cancel"
                font.pixelSize: Tokens.font.small
            }
        }

        MouseArea {
            id: drag

            property real ax
            property real ay
            property real bx
            property real by

            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.CrossCursor
            onPressed: e => {
                if (e.button === Qt.RightButton) {
                    root._endPick();
                    return;
                }
                ax = bx = e.x;
                ay = by = e.y;
            }
            onPositionChanged: e => {
                bx = e.x;
                by = e.y;
            }
            onReleased: e => {
                if (e.button !== Qt.LeftButton)
                    return;
                const big = picker.w >= 8 && picker.h >= 8;
                root._take(root.picking, big ? Qt.rect(picker.x0, picker.y0, picker.w, picker.h) : null);
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
