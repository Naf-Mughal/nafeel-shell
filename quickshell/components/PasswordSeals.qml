pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// A password as seals: each key presses in a seal's character in cinnabar
// (no ground), which then melts into a plain dot (the character shrinking
// and fading as the dot rounds out of it, cinnabar to ink), as the Pixel's
// PIN shapes melt into dots. Stays inside its field: the row slides so the newest is in view.
//   PasswordSeals { anchors.fill: parent; count: input.text.length }
Item {
    id: root

    property int count: 0
    property color dot: Colours.palette.m3onSurface
    readonly property bool animate: !Tokens.reduceMotion
    // The stamps' characters, taken in turn.
    readonly property string glyphs: "印道心气灵玄天剑云月风山"

    clip: true

    // One entry per key, added and removed at the end only (a count as the
    // model would remake every seal at each key: none would ever melt).
    ListModel {
        id: keys
    }
    onCountChanged: {
        while (keys.count < count)
            keys.append({});
        while (keys.count > count)
            keys.remove(keys.count - 1);
    }

    Row {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        // The newest seal stays in view; older ones slide out to the left.
        x: Math.min(0, root.width - width - 4)
        spacing: 6

        Behavior on x {
            enabled: root.animate
            Anim {
                duration: Tokens.anim.fast
            }
        }

        Repeater {
            model: keys

            Item {
                id: slot

                required property int index
                // 0: the seal as stamped, 1: the dot it settles into.
                property real melt: root.animate ? 0 : 1

                // As wide as its seal now: stamped, then the dot's width.
                width: stamp.size
                height: 18

                // The stamp's character in cinnabar, no ground, melting into
                // the dot: it shrinks and fades as the dot rounds out of it.
                Item {
                    id: stamp

                    anchors.centerIn: parent
                    readonly property real size: 14 - 6 * slot.melt

                    width: size
                    height: size
                    rotation: (slot.index % 2 ? 5 : -6) * (1 - slot.melt)

                    StyledText {
                        anchors.centerIn: parent
                        text: root.glyphs.charAt(slot.index % root.glyphs.length)
                        // Cinnabar never themes (components/Seal).
                        color: "#c8372d"
                        font.family: Tokens.font.cjk
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        opacity: 1 - slot.melt
                        scale: 1 - 0.6 * slot.melt
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 8
                        height: 8
                        radius: 4
                        color: Qt.tint("#c8372d", Qt.alpha(root.dot, slot.melt))
                        opacity: slot.melt
                        scale: 0.3 + 0.7 * slot.melt
                    }
                }

                Component.onCompleted: if (root.animate)
                    press.start()

                SequentialAnimation {
                    id: press

                    // Pressed in, a little over.
                    NumberAnimation {
                        target: stamp
                        property: "scale"
                        from: 1.5
                        to: 1
                        duration: Tokens.anim.fast
                        easing.type: Easing.OutBack
                        easing.overshoot: 2
                    }
                    PauseAnimation {
                        duration: Tokens.anim.normal
                    }
                    // Then melts into its dot.
                    NumberAnimation {
                        target: slot
                        property: "melt"
                        to: 1
                        duration: Tokens.anim.normal
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Tokens.anim.expressiveEffects
                    }
                }
            }
        }
    }
}
