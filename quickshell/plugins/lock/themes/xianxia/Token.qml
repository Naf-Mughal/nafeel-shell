import QtQuick
import "../.."

// A lock button made as the cards beside it (CoverCard): the cover, the
// glyph large and its name inside, at the card rounding (rounder while
// pressed); qi gathers over it from the left as it's held (`hold`, the
// session's: it confirms once full) or in a quick sweep when pressed.
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

    width: 78 * sc
    height: 100 * sc

    CoverCard {
        anchors.fill: parent
        sc: token.sc
        hovered: area.containsMouse
        radius: area.pressed ? Xian.radiusMorph : Xian.radiusNormal

        underlay: Rectangle {
            readonly property color qi: token.live ? Xian.cinnabar : token.tone

            width: parent.width * token.progress
            height: parent.height
            visible: token.progress > 0.001
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Xian.alpha(qi, 0.04) }
                GradientStop { position: 0.8; color: Xian.alpha(qi, 0.22) }
                GradientStop { position: 1; color: Xian.alpha(qi, 0.4) }
            }

            // Its edge.
            Rectangle {
                anchors.right: parent.right
                width: 2 * token.sc
                height: parent.height
                color: parent.qi
                opacity: 0.8
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
