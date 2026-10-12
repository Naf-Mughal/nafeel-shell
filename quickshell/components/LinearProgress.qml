import QtQuick
import qs.config
import qs.services

// An M3 linear progress (Caelestia's StyledProgressBar, on the shell's roles):
// the value in `fg`, a gap, the track, and a stop dot at the end.
//
//   LinearProgress { width: 160; value: 0.6 }
Item {
    id: root

    property real value
    property color fg: Colours.roleInk("primary", "ghost")
    property color track: Colours.roleFill("secondary", "soft", 0)
    property real gap: 4
    property real shown: Math.max(0, Math.min(1, isNaN(value) ? 0 : value))

    implicitWidth: 160
    implicitHeight: 6

    Behavior on shown {
        Anim {}
    }

    Rectangle {
        id: active

        visible: width > 0
        width: Math.max(0, (root.width - root.gap) * root.shown)
        height: root.height
        radius: height / 2
        color: root.fg
    }

    Rectangle {
        x: active.width + (active.width > 0 ? root.gap : 0)
        width: Math.max(0, root.width - x)
        height: root.height
        radius: height / 2
        color: root.track
    }

    // The stop.
    Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.height * 0.66
        height: width
        radius: width / 2
        color: root.fg
        visible: root.shown < 0.98
    }
}
