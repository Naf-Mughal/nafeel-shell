import QtQuick
import qs.config
import qs.services
import qs.components

// The OSD inside a panel that comes out where the OSD would (the dashboard,
// the wallpaper picker): one panel, not a pill over it. Built like the
// panels' buttons: a paper Surface on the shell's rounding, as tall as the
// heading's controls, centred in the room it's given and fading in and out.
Surface {
    id: root

    // The heading's control height (the dashboard's tabs: 52).
    property int controlHeight: 40

    anchors.centerIn: parent
    width: Math.min(parent.width, view.implicitWidth)
    height: controlHeight
    role: "paper"
    emphasis: "strong"
    level: 3
    radius: Tokens.rounding.morph
    clip: true
    opacity: (Plugins.instance("osd")?.shown ?? false) ? 1 : 0
    scale: (Plugins.instance("osd")?.shown ?? false) ? 1 : 0.92
    visible: opacity > 0

    Behavior on opacity {
        Anim {
            duration: Tokens.anim.fast
        }
    }

    OsdView {
        id: view

        anchors.centerIn: parent
        width: implicitWidth
        height: parent.height
        pad: Tokens.spacing.normal
        sliderWidth: 180
        buttonSize: Math.min(40, root.controlHeight - 12)
        labelWidth: Math.max(80, root.parent.width - 2 * Tokens.spacing.normal - 40)
    }
}
