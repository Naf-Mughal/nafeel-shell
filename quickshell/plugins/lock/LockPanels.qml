pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// The lock's panels, grown out of its frame as the desktop's drawers grow
// out of the bars (each is one of the frame's panel slots, so its paper is
// the frame's, merged with it): out of the top, the OSD and the
// notifications; out of the left, capture (the capture keys open it: a
// region screenshot first). Over everything, the region picker.
Item {
    id: root

    required property var frame
    property var ctx: null

    readonly property real border: Tokens.border
    readonly property real leftInset: frame?.leftInset ?? Tokens.border
    readonly property real pad: Tokens.spacing.large
    readonly property var notifs: Plugins.instance("notifications")?.notifs ?? null
    readonly property var osd: Plugins.instance("osd")
    readonly property var capture: Plugins.instance("capture")?.capture ?? null

    // The frame's slots: the top panel and the capture panel.
    Binding {
        target: root.frame
        property: "p0"
        value: Qt.vector4d(top.x, 0, top.width, top.shown > 0.5 ? root.border + top.shown : 0)
    }
    Binding {
        target: root.frame
        property: "p1"
        value: Qt.vector4d(0, cap.y, cap.shown > 0.5 ? root.leftInset + cap.shown : 0, cap.height)
    }

    // ── Out of the top: the OSD, then the notifications ──
    Item {
        id: top

        readonly property var popups: (root.notifs?.popups ?? []).slice(0, 3)
        readonly property bool showsOsd: root.osd?.shown ?? false
        readonly property bool wanted: showsOsd || popups.length > 0
        readonly property real full: topBody.implicitHeight + root.pad * 2
        // How far out it is (px past the border).
        property real shown: wanted ? full : 0

        Behavior on shown {
            SpringAnimation {
                spring: Tokens.spring.spatial.spring
                damping: Tokens.spring.spatial.damping
                epsilon: 0.25
            }
        }

        x: (parent.width - width) / 2
        y: root.border
        width: 460
        height: shown
        clip: true
        visible: shown > 0.5

        Column {
            id: topBody

            x: root.pad
            y: root.pad - (top.full - top.shown)
            width: top.width - root.pad * 2
            spacing: Tokens.spacing.normal

            Loader {
                anchors.horizontalCenter: parent.horizontalCenter
                active: top.showsOsd && Plugins.isEnabled("osd")
                visible: active
                source: Qt.resolvedUrl("../osd/OsdView.qml")
            }

            Hairline {
                width: parent.width
                visible: top.showsOsd && top.popups.length > 0
            }

            Repeater {
                model: top.popups

                // One notification, quiet: its picture, app and time, summary
                // and body; no actions (they can't run behind the lock).
                Item {
                    id: note

                    required property var modelData

                    width: topBody.width
                    height: Math.max(44, noteText.implicitHeight)

                    ClippingRectangle {
                        id: pic

                        width: 44
                        height: 44
                        radius: Tokens.rounding.small
                        color: Colours.palette.m3secondaryContainer

                        Image {
                            anchors.fill: parent
                            visible: note.modelData.image !== ""
                            source: note.modelData.image ?? ""
                            sourceSize: Qt.size(88, 88)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }

                        IconImage {
                            anchors.centerIn: parent
                            visible: !note.modelData.image && !!note.modelData.icon
                            implicitSize: 28
                            source: note.modelData.icon ? (note.modelData.icon.startsWith("/") ? "file://" + note.modelData.icon : Quickshell.iconPath(note.modelData.icon, "dialog-information")) : ""
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            visible: !note.modelData.image && !note.modelData.icon
                            text: "notifications"
                            fill: 1
                            color: Colours.palette.m3onSecondaryContainer
                        }
                    }

                    Column {
                        id: noteText

                        anchors.left: pic.right
                        anchors.leftMargin: Tokens.spacing.normal
                        anchors.right: close.left
                        anchors.rightMargin: Tokens.spacing.small
                        spacing: 1

                        MicroLabel {
                            text: note.modelData.app ?? ""
                        }

                        StyledText {
                            width: parent.width
                            elide: Text.ElideRight
                            text: note.modelData.summary ?? ""
                            font.family: Tokens.font.serif
                            font.pixelSize: Tokens.font.body + 1
                        }

                        StyledText {
                            width: parent.width
                            visible: text !== ""
                            text: note.modelData.body ?? ""
                            color: Colours.palette.m3onSurfaceVariant
                            font.pixelSize: Tokens.font.small
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }
                    }

                    IconButton {
                        id: close

                        anchors.right: parent.right
                        anchors.top: parent.top
                        icon: "close"
                        size: 28
                        onClicked: root.notifs?.hidePopup(note.modelData)
                    }
                }
            }
        }
    }

    // ── Out of the left: capture ──
    property bool capOpen: false
    property int capIndex: 0
    property Item _focusWas: null
    readonly property var capChoices: [
        {
            icon: "screenshot_region",
            title: "Screenshot a region",
            event: "screenshot",
            region: true
        },
        {
            icon: "fullscreen",
            title: "Screenshot the screen",
            event: "screenshot",
            region: false
        },
        {
            icon: "screen_record",
            title: "Record a region",
            event: "record",
            region: true
        },
        {
            icon: "videocam",
            title: "Record the screen",
            event: "record",
            region: false
        }
    ]

    function openCapture(preset: string): void {
        capIndex = preset === "record-region" ? 2 : 0;
        _focusWas = Window.window?.activeFocusItem ?? null;
        capOpen = true;
        capKeys.forceActiveFocus();
    }

    function closeCapture(): void {
        capOpen = false;
        _focusWas?.forceActiveFocus();
    }

    function choose(i: int): void {
        const c = capChoices[i];
        closeCapture();
        if (c.region)
            pick(c.event);
        else
            take(c.event, null);
    }

    Connections {
        target: root.capture

        function onLockPanelRequested(preset: string): void {
            root.ctx?.poke();
            root.openCapture(preset);
        }
    }

    Item {
        id: cap

        readonly property real full: 300
        property real shown: root.capOpen ? full : 0

        Behavior on shown {
            SpringAnimation {
                spring: Tokens.spring.spatial.spring
                damping: Tokens.spring.spatial.damping
                epsilon: 0.25
            }
        }

        x: root.leftInset
        y: (parent.height - height) / 2
        width: shown
        height: capBody.implicitHeight + root.pad * 2
        clip: true
        visible: shown > 0.5

        Item {
            id: capKeys

            focus: root.capOpen
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape)
                    root.closeCapture();
                else if (event.key === Qt.Key_Up)
                    root.capIndex = (root.capIndex + root.capChoices.length - 1) % root.capChoices.length;
                else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab)
                    root.capIndex = (root.capIndex + 1) % root.capChoices.length;
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    root.choose(root.capIndex);
                else
                    return;
                event.accepted = true;
            }
        }

        Column {
            id: capBody

            x: root.pad - (cap.full - cap.shown)
            y: root.pad
            width: cap.full - root.pad * 2
            spacing: Tokens.spacing.small

            Row {
                spacing: Tokens.spacing.small

                StyledText {
                    anchors.baseline: capTitle.baseline
                    text: "影"
                    color: Colours.palette.m3primary
                    font.family: Tokens.font.cjk
                    font.pixelSize: 20
                }

                StyledText {
                    id: capTitle

                    text: "Capture"
                    font.family: Tokens.font.serif
                    font.pixelSize: Tokens.font.title
                }
            }

            Item {
                width: parent.width
                height: rows.height

                ListGoo {
                    id: goo

                    anchors.fill: rows
                    container: rows
                }

                Column {
                    id: rows

                    width: parent.width

                    Repeater {
                        model: root.capChoices

                        ListRow {
                            required property var modelData
                            required property int index

                            width: rows.width
                            implicitHeight: 42
                            goo: goo
                            picked: index === root.capIndex
                            icon: modelData.icon
                            title: modelData.title
                            onClicked: root.choose(index)
                        }
                    }
                }
            }

            MicroLabel {
                text: "↑ ↓ to pick · Enter · Esc"
            }
        }
    }

    // ── The region picker (the lock's own: nothing else can draw over
    // it): drag one out; a click without dragging takes the whole screen;
    // Esc or a right-click lets it go ──
    property string picking: ""

    function pick(event: string): void {
        _focusWas = Window.window?.activeFocusItem ?? _focusWas;
        picking = event;
        picker.forceActiveFocus();
    }

    function _endPick(): void {
        picking = "";
        _focusWas?.forceActiveFocus();
    }

    function take(event: string, area: var): void {
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
        onTriggered: root.capture?.lockedCapture(event, Window.window?.screen?.name ?? "", area)
    }

    Item {
        id: picker

        anchors.fill: parent
        visible: root.picking !== ""
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
            y: 28
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
                const ev = root.picking;
                const big = picker.w >= 8 && picker.h >= 8;
                const area = big ? Qt.rect(picker.x0, picker.y0, picker.w, picker.h) : null;
                root._endPick();
                root.take(ev, area);
            }
        }
    }
}
