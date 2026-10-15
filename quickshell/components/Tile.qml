import QtQuick
import qs.config
import qs.services

// An M3 Expressive toggle tile (a Surface): icon, label and state line. On,
// it fills with primary, the ink spreading from where it was pressed (and
// drawing back there when it's turned off), and its corners round out
// further; the state line is brushed over when it changes (InkSwap).
Surface {
    id: root

    property string icon
    property string label
    property string sublabel
    property bool checked
    // Icon above the label, centred: for tiles three or more across.
    property bool stacked: false

    // The fill's spread: 0 off, 1 on.
    property real spread: checked ? 1 : 0
    Behavior on spread {
        enabled: !Tokens.reduceMotion
        Anim {
            duration: Tokens.anim.normal
            easing.bezierCurve: root.checked ? Tokens.anim.emphasizedDecel : Tokens.anim.emphasizedAccel
        }
    }

    role: "paper"
    emphasis: "strong"
    level: 3
    // The ink turns once the fill has spread under it.
    baseInk: spread > 0.5 ? Colours.roleInk("primary", "strong") : Colours.roleInk("paper", "strong")
    baseSubInk: spread > 0.5 ? Colours.roleSubInk("primary", "strong") : Colours.roleSubInk("paper", "strong")
    interactive: true
    pressDepth: 0.97
    implicitHeight: 64
    shapeRadius: checked ? Tokens.rounding.large : pressed ? Tokens.rounding.small : Tokens.rounding.normal

    InkSpread {
        color: Colours.roleFill("primary", "strong", 0)
        origin: root.pressPoint
        p: root.spread
        r1: root.radius
    }

    Column {
        visible: root.stacked
        anchors.centerIn: parent
        spacing: 2

        MaterialIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.icon
            fill: root.checked ? 1 : 0
            color: root.ink
            size: 22
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            color: root.ink
            font.pixelSize: Tokens.font.small
            font.weight: Font.DemiBold
        }
    }

    Row {
        visible: !root.stacked
        anchors.left: parent.left
        anchors.leftMargin: Tokens.spacing.large
        anchors.right: parent.right
        anchors.rightMargin: Tokens.spacing.normal
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spacing.normal

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            fill: root.checked ? 1 : 0
            color: root.ink
            size: 22
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 22 - Tokens.spacing.normal

            StyledText {
                width: parent.width
                text: root.label
                color: root.ink
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            InkSwap {
                width: parent.width
                visible: root.sublabel !== ""
                text: root.sublabel
                color: root.subInk
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }
    }
}
