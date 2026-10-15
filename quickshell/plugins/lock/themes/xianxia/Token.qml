import QtQuick
import "../.."

// A lock button made as the cards beside it (CoverCard): the cover, the
// glyph large and its name inside, square at the cards' height, at the card
// rounding (rounder while pressed); qi gathers out from its centre as it's
// held (`hold`, the session's: it confirms once full) or in a quick swell
// when pressed.
// `live` (recording) fills it cinnabar and `label` can say the time.
Item {
    id: token

    property string glyph
    property string label
    property real sc: 1
    property bool hold: false
    property bool live: false
    property bool enabled: true
    property color tone: Xian.gold
    signal activated

    readonly property real progress: live ? 1 : hold ? area.progress : tap
    property real tap: 0

    width: 100 * sc
    height: 100 * sc

    CoverCard {
        anchors.fill: parent
        sc: token.sc
        hovered: area.containsMouse
        radius: area.pressed ? Xian.radiusMorph : Xian.radiusNormal

        // Qi, gathering out from the centre: a faint pool, its rim bright.
        underlay: Rectangle {
            readonly property color qi: token.live ? Xian.cinnabar : token.tone

            anchors.centerIn: parent
            width: Math.hypot(parent.width, parent.height) * token.progress
            height: width
            radius: width / 2
            visible: token.progress > 0.001
            color: Xian.alpha(qi, 0.2)
            border.width: 2 * token.sc
            border.color: Xian.alpha(qi, 0.75)

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.7
                height: width
                radius: width / 2
                color: Xian.alpha(parent.qi, 0.08)
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 6 * token.sc

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: token.glyph
            font.family: Xian.cjk
            font.weight: Font.Black
            font.pixelSize: 28 * token.sc
            color: token.live ? Xian.paper : area.containsMouse ? Xian.goldHi : token.tone
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: token.label.toUpperCase()
            font.family: Xian.serif
            font.pixelSize: 10 * token.sc
            font.letterSpacing: 1.5 * token.sc
            color: token.live ? Xian.paper : Xian.paperDim
        }
    }

    HoldArea {
        id: area

        anchors.fill: parent
        enabled: token.enabled
        holdMs: token.hold ? 750 : 1
        onConfirmed: token.activated()
        onPressed: if (!token.hold) sweep.restart()
    }

    SequentialAnimation {
        id: sweep

        NumberAnimation {
            target: token
            property: "tap"
            from: 0
            to: 1
            duration: Xian.d(280)
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: token
            property: "tap"
            to: 0
            duration: Xian.d(320)
        }
    }
}
