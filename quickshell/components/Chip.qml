import QtQuick
import qs.config
import qs.services

// A small chip to pick or filter with, on the shell's rounding (like the
// tabs). Selected, it fills with the secondary container, the ink spreading
// from where it was pressed (and drawing back there when it's let go), and
// shows it: its icon fills in, or a check slides in where it has none.
// Optional leading icon. In a ChipGroup the group's goo is the fill
// (`inkFill: false`).
Surface {
    id: root

    property string text
    property string icon
    property bool selected
    property bool inkFill: true

    // The selected fill's spread: 0 none, 1 all.
    property real spread: selected ? 1 : 0
    Behavior on spread {
        enabled: root.inkFill && !Tokens.reduceMotion
        Anim {
            duration: Tokens.anim.normal
            easing.bezierCurve: root.selected ? Tokens.anim.emphasizedDecel : Tokens.anim.emphasizedAccel
        }
    }

    role: "paper"
    level: 3
    shapeRadius: pressed ? Tokens.rounding.small : Tokens.rounding.morph
    interactive: true
    pressDepth: 0.92
    implicitHeight: 32
    implicitWidth: row.implicitWidth + Tokens.spacing.large * 2
    // The ink turns once the fill has spread under it.
    baseInk: inkFill && spread > 0.5 ? Colours.roleInk("secondary", "soft") : Colours.roleInk("paper", "soft")
    baseSubInk: inkFill && spread > 0.5 ? baseInk : Colours.roleSubInk("paper", "soft")

    InkSpread {
        visible: root.inkFill && p > 0.001
        color: Colours.roleFill("secondary", "soft", 0)
        origin: root.pressPoint
        p: root.spread
        r1: root.radius
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        // A check where there's no icon, sliding in while selected.
        Item {
            visible: root.icon === "" && width > 0.5
            anchors.verticalCenter: parent.verticalCenter
            width: root.selected ? 16 : 0
            height: 16
            clip: true

            Behavior on width {
                Anim {
                    duration: Tokens.anim.fast
                }
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: "check"
                color: root.ink
                size: 16
            }
        }

        MaterialIcon {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            fill: root.selected ? 1 : 0
            color: root.ink
            size: 16
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.selected ? root.ink : root.subInk
            font.pixelSize: Tokens.font.small
            font.weight: root.selected ? Font.DemiBold : Font.Normal
        }
    }
}
