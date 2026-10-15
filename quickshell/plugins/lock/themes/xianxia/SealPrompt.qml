import QtQuick
import "../.."

// Under the formation: the state in the formation's words (诵咒解封,
// 运转周天, 破阵中, 闭关), what's happening, a warning in cinnabar (a wrong
// incantation, Caps Lock, the last stick, seclusion); once granted, the
// cultivation gained. The lock's, shared with the polkit prompt. `ctx` as
// LockContext's (phase, cells, combo, lockedOut, lockoutClock, message,
// capsLock, lastLife, unlockTime, reward).
Item {
    id: xian

    required property var ctx
    property real sc: 1
    property real rewardIn: 0
    // The idle line ("Recite the incantation to break the seal").
    property string idleLine: "Recite the incantation to break the seal"
    readonly property bool granted: ctx.phase === "granted" || ctx.phase === "exiting"
    readonly property var reward: ctx.reward ?? null
    readonly property Item promptArea: xian

    width: 900 * sc
    height: 86 * sc

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6 * xian.sc
        visible: !xian.granted

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            readonly property var c: xian.ctx
            text: c.phase === "verifying" ? "破阵中"
                : c.lockedOut && c.cells === 0 ? "闭关"
                : c.cells > 0 ? "运转周天"
                : "诵咒解封"
            font.family: Xian.cjk
            font.weight: Font.Medium
            font.pixelSize: 22 * xian.sc
            font.letterSpacing: 8 * xian.sc
            color: c.lockedOut && c.cells === 0 ? Xian.cinnabar : Xian.gold

            // The other lines' glyphs, drawn (all but invisible)
            // from the start, so the first keystroke doesn't
            // rasterise them.
            Text {
                text: "运转周天破阵中闭关"
                font: parent.font
                color: parent.color
                opacity: 0.004
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            readonly property var c: xian.ctx
            text: c.phase === "verifying" ? "The formation weighs your incantation…"
                : c.lockedOut && c.cells === 0 ? "Closed-door seclusion. The seal reopens in " + (c.lockoutClock || "time")
                : c.cells > 0 ? c.cells + (c.cells === 1 ? " rune" : " runes") + " kindled" + (c.combo >= 5 ? "  ·  unbroken circulation ×" + c.combo : "")
                : xian.idleLine
            width: Math.min(implicitWidth, xian.width)
            elide: Text.ElideRight
            font.family: Xian.serif
            font.italic: true
            font.pixelSize: 15 * xian.sc
            color: Xian.paperDim
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            readonly property var c: xian.ctx
            text: c.message.length > 0 ? c.message
                : c.capsLock ? "Caps Lock is on. Incantations are case-sensitive"
                : c.lastLife ? "One incense stick remains. Another failure means " + LockTheme.span(c.unlockTime) + " of seclusion"
                : ""
            font.family: Xian.serif
            font.pixelSize: 14 * xian.sc
            color: Xian.cinnabar
        }
    }

    // Cultivation gained.
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6 * xian.sc
        visible: xian.granted && xian.reward !== null
        opacity: xian.rewardIn

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "修为 +" + Math.round((xian.reward ? xian.reward.total : 0) * Math.min(1, xian.rewardIn * 1.3))
            font.family: Xian.cjk
            font.weight: Font.Black
            font.pixelSize: 34 * xian.sc
            color: Xian.goldHi
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, promptArea.width)
            elide: Text.ElideRight
            text: xian.reward
                ? xian.reward.lines.map(l => l.label.toLowerCase() + " +" + l.xp).join("  ·  ")
                  + (xian.reward.multiplier > 1 ? "  ·  streak ×" + xian.reward.multiplier.toFixed(2) : "")
                : ""
            font.family: Xian.serif
            font.italic: true
            font.pixelSize: 14 * xian.sc
            color: Xian.paperDim
        }
    }
}
