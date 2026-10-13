import QtQuick
import qs.config
import qs.services

// A bar layout chip (the bar studio, the edit mode on the bar): an icon
// (filled) or a panel (outlined), from BarLayout's chips ({ kind, id, icon,
// label }). Click it to pick it (`pick`); drag it and let go on a drop
// target: its face floats in `overlay` while dragged (so nothing positions
// or clips it), and the target under it is read, the face put back, and
// then the target's `accept(info)` called (the move remakes the chips, this
// one included). Dropped on, it says so (`droppedOn`).
Item {
    id: chip

    required property var info
    // Where the face floats while dragged (above everything around it).
    required property Item overlay
    property bool isPicked: false
    property int size: 26

    signal pick
    signal droppedOn(var info)

    width: size
    height: size

    // Another chip dropped on this one.
    DropArea {
        function accept(c: var): void {
            if (!(c.kind === chip.info.kind && c.id === chip.info.id))
                chip.droppedOn(c);
        }

        anchors.fill: parent
    }

    Surface {
        id: face

        // What a drop reads.
        readonly property var info: chip.info

        width: chip.width
        height: chip.height
        role: chip.isPicked ? "primary" : chip.info.kind === "panel" ? "tertiary" : "secondary"
        emphasis: chip.isPicked ? "strong" : chip.info.kind === "panel" ? "ghost" : "soft"
        outlined: chip.info.kind === "panel" && !chip.isPicked
        shape: "small"
        scale: grab.drag.active ? 1.2 : grab.containsMouse ? 1.08 : 1

        Behavior on scale {
            Anim {
                duration: Tokens.anim.fast
            }
        }

        Drag.active: grab.drag.active
        Drag.source: face
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2

        MaterialIcon {
            anchors.centerIn: parent
            text: chip.info.icon
            size: Math.round(chip.size * 0.6)
            fill: chip.info.kind === "panel" ? 0 : 1
            color: face.ink
        }
    }

    MouseArea {
        id: grab

        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        drag.target: face
        onPressed: {
            const p = face.mapToItem(chip.overlay, 0, 0);
            face.parent = chip.overlay;
            face.x = p.x;
            face.y = p.y;
        }
        onReleased: {
            const dragged = drag.active;
            const target = face.Drag.target;
            const info = chip.info;
            face.parent = chip;
            face.x = 0;
            face.y = 0;
            if (!dragged)
                chip.pick();
            else if (target && typeof target.accept === "function")
                Qt.callLater(() => target.accept(info));
        }
        onCanceled: {
            face.parent = chip;
            face.x = 0;
            face.y = 0;
        }
    }
}
