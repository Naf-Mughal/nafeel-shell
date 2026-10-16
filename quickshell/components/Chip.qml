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

    // The selected fill: made when it's first needed and let go once it has
    // drawn back (an unselected chip, nearly all of them, carries none).
    Loader {
        anchors.fill: parent
        active: root.inkFill && (root.selected || root.spread > 0.001)
        sourceComponent: InkSpread {
            visible: root.inkFill && p > 0.001
            color: Colours.roleFill("secondary", "soft", 0)
            origin: root.pressPoint
            p: root.spread
            r1: root.radius
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        // A check where there's no icon, sliding in while selected; not in a
        // goo group (there `selected` follows the goo, and a chip widening
        // under it moved the goo, which unselected it: a loop that spun the
        // GUI thread at 100%). Made the first time it's selected, and kept
        // (a Material icon, a clip and a Behavior in every unselected chip
        // was most of a chip's weight).
        property bool checkMade: false
        readonly property bool wantsCheck: root.icon === "" && root.inkFill && root.selected
        onWantsCheckChanged: {
            if (wantsCheck)
                checkMade = true;
        }
        Component.onCompleted: checkMade = wantsCheck

        Loader {
            anchors.verticalCenter: parent.verticalCenter
            active: row.checkMade && root.icon === "" && root.inkFill
            visible: item && item.width > 0.5
            width: item ? item.width : 0
            height: 16
            sourceComponent: Item {
                // Starts closed and opens a moment after it's made, so the
                // first selection slides in like the rest.
                property bool open: false

                width: open ? 16 : 0
                height: 16
                clip: true
                Component.onCompleted: Qt.callLater(() => open = Qt.binding(() => root.selected && root.inkFill))

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
        }

        // The leading icon, when it has one.
        Loader {
            anchors.verticalCenter: parent.verticalCenter
            active: root.icon !== ""
            visible: active
            sourceComponent: MaterialIcon {
                text: root.icon
                fill: root.selected ? 1 : 0
                color: root.ink
                size: 16
            }
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.selected ? root.ink : root.subInk
            font.pixelSize: Tokens.font.small
            // One weight in a goo group (a bolder label is wider: the same loop).
            font.weight: root.selected && root.inkFill ? Font.DemiBold : Font.Normal
        }
    }
}
