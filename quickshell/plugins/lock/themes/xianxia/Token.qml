import QtQuick
import "../.."

// A lock button on the shell's primitives' look: a square of paper at a
// control's rounding (rounder while pressed), its glyph, a caption under it,
// and the theme's ink spreading from the centre: while held (`hold`, the
// session actions: it confirms once full) or as a quick press. `live`
// tints it cinnabar (recording).
Column {
    id: token

    property string glyph
    property string label
    property real sc: 1
    property bool hold: false
    property bool live: false
    property bool enabled: true
    property color tone: Xian.gold
    signal activated

    readonly property real progress: hold ? area.progress : tap
    property real tap: 0

    spacing: 6 * sc

    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 50 * token.sc
        height: width

        Rectangle {
            id: face

            anchors.fill: parent
            radius: area.pressed ? Xian.radiusMorph : Xian.radiusSmall
            color: token.live ? Xian.alpha(Xian.cinnabar, 0.5) : Xian.paperFill
            border.width: 1
            border.color: area.containsMouse ? Xian.alpha(token.tone, 0.5) : Xian.alpha(Xian.paper, 0.1)
            clip: true

            Behavior on radius {
                NumberAnimation {
                    duration: Xian.d(160)
                    easing.type: Easing.OutCubic
                }
            }

            // The ink, from the centre.
            Rectangle {
                anchors.centerIn: parent
                width: Math.hypot(parent.width, parent.height) * token.progress
                height: width
                radius: width / 2
                color: Xian.alpha(token.tone, 0.32)
                visible: token.progress > 0.001
            }
        }

        Text {
            anchors.centerIn: parent
            text: token.glyph
            font.family: Xian.cjk
            font.weight: Font.Black
            font.pixelSize: 20 * token.sc
            color: token.live ? Xian.paper : area.containsMouse ? Xian.goldHi : token.tone
        }

        HoldArea {
            id: area

            anchors.fill: parent
            enabled: token.enabled
            holdMs: token.hold ? 750 : 1
            onConfirmed: token.activated()
            onPressed: if (!token.hold) tapInk.restart()
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: token.label
        font.family: Xian.serif
        font.italic: !token.live
        font.pixelSize: 12 * token.sc
        color: token.live ? Xian.cinnabar : Xian.paperDim
    }

    SequentialAnimation {
        id: tapInk

        NumberAnimation {
            target: token
            property: "tap"
            from: 0
            to: 1
            duration: Xian.d(260)
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: token
            property: "tap"
            to: 0
            duration: Xian.d(260)
        }
    }
}
