import QtQuick
import qs.config
import qs.services
import "hosts.js" as Hosts

// A small label for something that's only an icon: shown after the pointer
// rests on `target` a moment, above it (below where there's no room), inside
// its panel (hosts.js); it rises in and fades, and never takes a click.
//   IconButton { id: b; icon: "delete"; Tooltip { target: b; text: "Forget" } }
Item {
    id: root

    property Item target: parent
    property string text
    property int delay: 500

    readonly property bool shown: rest.ready && hover.hovered && text !== ""

    HoverHandler {
        id: hover

        parent: root.target
        onHoveredChanged: {
            if (hovered) {
                root.host = Hosts.of(root.target);
                rest.restart();
            } else {
                rest.stop();
                rest.ready = false;
            }
        }
    }

    Timer {
        id: rest

        property bool ready: false

        interval: root.delay
        onTriggered: ready = true
    }

    property Item host: null

    StyledRect {
        id: tip

        readonly property rect a: root.shown && root.host ? root.target.mapToItem(root.host, 0, 0, root.target.width, root.target.height) : Qt.rect(0, 0, 0, 0)
        readonly property bool below: a.y - height - 6 < 4

        parent: root.host
        z: 1001
        x: Math.max(4, Math.min((root.host?.width ?? 0) - width - 4, a.x + (a.width - width) / 2))
        y: (below ? a.y + a.height + 6 : a.y - height - 6) + (1 - opacity) * (below ? -4 : 4)
        width: label.implicitWidth + 16
        height: label.implicitHeight + 8
        radius: Tokens.rounding.small
        color: Colours.palette.m3inverseSurface
        opacity: root.shown ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity {
            Anim {
                duration: Tokens.anim.fast
            }
        }

        StyledText {
            id: label

            anchors.centerIn: parent
            text: root.text
            color: Colours.palette.m3inverseOnSurface
            font.pixelSize: Tokens.font.small
        }
    }
}
