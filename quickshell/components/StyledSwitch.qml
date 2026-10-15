import QtQuick
import qs.config
import qs.services
import "keynav.js" as KeyNav

// A switch, in ink: the thumb is a drop that springs along the track, drawn
// out sideways while it moves (no tilt), and the track soaks with colour up
// to where the drop is, so turning it on reads as ink running into the
// paper. Hover swells the drop; Space or Enter toggles it from the keyboard.
Item {
    id: root

    property bool checked
    signal toggled

    // Where the drop is: 0 off, 1 on (springing after `checked`).
    property real pos: checked ? 1 : 0
    Behavior on pos {
        enabled: !Tokens.reduceMotion
        SpringAnimation {
            spring: Tokens.springK(4.5)
            damping: Tokens.dampK(0.38)
            epsilon: 0.002
        }
    }
    // How far it is from where it's going (draws the drop out).
    readonly property real lag: Math.abs((checked ? 1 : 0) - pos)

    readonly property real pad: 4
    readonly property real dropSize: (checked ? 22 : 16) + (hover.hovered ? 2 : 0)
    readonly property real travel: width - pad * 2 - 22

    implicitWidth: 52
    implicitHeight: 32

    property bool focusByKey: false
    activeFocusOnTab: true
    onActiveFocusChanged: {
        if (!activeFocus)
            focusByKey = false;
    }
    Keys.onPressed: event => {
        const k = event.key;
        if (k === Qt.Key_Space || k === Qt.Key_Return || k === Qt.Key_Enter)
            toggled();
        else if (k === Qt.Key_Down || k === Qt.Key_Tab)
            KeyNav.move(root, true);
        else if (k === Qt.Key_Up || k === Qt.Key_Backtab)
            KeyNav.move(root, false);
        else
            return;
        event.accepted = true;
    }

    // The track: paper with a hairline, soaking with colour behind the drop.
    StyledRect {
        id: track

        anchors.fill: parent
        radius: height / 2
        color: Colours.palette.m3surfaceContainerHighest
        border.width: root.activeFocus && root.focusByKey ? 2 : Tokens.hairline * 2
        border.color: root.activeFocus && root.focusByKey ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outline, 1 - root.pos)

        StyledRect {
            // Soaked up to the drop's far edge, fading in as it goes on (no
            // sliver left behind at the start).
            width: Math.max(height, drop.x + drop.width + root.pad)
            height: parent.height
            radius: height / 2
            color: Colours.palette.m3primary
            opacity: Math.min(1, root.pos * 1.6)
        }
    }

    // The drop.
    StyledRect {
        id: drop

        readonly property real stretch: root.lag * 14

        anchors.verticalCenter: parent.verticalCenter
        x: root.pad + (22 - root.dropSize) / 2 + root.pos * root.travel - (root.checked ? stretch : 0)
        width: root.dropSize + stretch
        height: root.dropSize
        radius: height / 2
        color: root.pos > 0.5 ? Colours.palette.m3onPrimary : Colours.palette.m3outline

        Behavior on height {
            Anim {
                duration: Tokens.anim.fast
                easing.bezierCurve: Tokens.anim.expressiveFastSpatial
            }
        }
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: root.toggled()
    }
}
