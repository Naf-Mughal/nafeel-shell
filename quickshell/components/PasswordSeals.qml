pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// A password as seals: each key presses in a cinnabar seal stamped with a
// character, which then morphs into a plain dot (square to circle, the
// stamp's character fading, cinnabar to ink), as the Pixel's PIN shapes melt
// into dots. Stays inside its field: the row slides so the newest is in view.
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

                Rectangle {
                    id: stamp

                    anchors.centerIn: parent
                    readonly property real size: 16 - 8 * slot.melt

                    width: size
                    height: size
                    radius: 2 + (size / 2 - 2) * slot.melt
                    rotation: (slot.index % 2 ? 5 : -6) * (1 - slot.melt)
                    // Cinnabar never themes (components/Seal), melting to ink.
                    color: Qt.tint("#c8372d", Qt.alpha(root.dot, slot.melt))
                    scale: 1

                    StyledText {
                        anchors.centerIn: parent
                        text: root.glyphs.charAt(slot.index % root.glyphs.length)
                        color: "#f3e6cf"
                        font.family: Tokens.font.cjk
                        font.pixelSize: 11
                        opacity: 1 - slot.melt * 2.5
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
