import QtQuick
import qs.config
import qs.services

// An M3 switch.
StyledRect {
    id: root

    property bool checked
    signal toggled

    implicitWidth: 52
    implicitHeight: 32
    radius: Math.min(height / 2, Tokens.rounding.morph)
    color: checked ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHighest
    border.width: checked ? 0 : 2
    border.color: Colours.palette.m3outline

    StyledRect {
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - width - 4 : 4
        width: root.checked ? 24 : 16
        height: width
        radius: Math.min(width / 2, Tokens.rounding.morph)
        color: root.checked ? Colours.palette.m3onPrimary : Colours.palette.m3outline

        Behavior on x {
            Anim {
                easing.bezierCurve: Tokens.anim.expressiveFastSpatial
            }
        }
        Behavior on width {
            Anim {
                duration: Tokens.anim.fast
            }
        }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: root.toggled()
    }
}
