import QtQuick
import Quickshell
import qs.services

// The enabled plugins' items for `slot` (Plugins.forSlot), in order. A
// Repeater, so its items join whatever lays it out (a Column, or a bar
// capsule, whose pill then finds the controls in them). Each item gets
// `shellScreen` and, when it has them, the capsule's inks (`group`).
Repeater {
    id: root

    required property string slot
    property ShellScreen shellScreen
    // The BarGroup it sits in, if any.
    property Item group: null

    model: Plugins.forSlot(slot)

    Loader {
        required property var modelData

        // The slot's width, when it has one (a bar capsule), so an item can
        // lay itself out across it.
        width: parent?.width > 0 ? parent.width : undefined
        Component.onCompleted: setSource(modelData.url, {
            shellScreen: root.shellScreen
        })
        onLoaded: {
            if (root.group && "groupInk" in item) {
                item.groupInk = Qt.binding(() => root.group.ink);
                item.groupActiveInk = Qt.binding(() => root.group.pillInk);
            }
        }
    }
}
