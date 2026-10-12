import QtQuick
import qs.config

// M3 Expressive press physics for its parent: a slight squash while pressed
// that springs back past rest and settles (give the parent a spring
// Behavior on scale). Bind `pressed`.
Item {
    id: root

    property bool pressed
    property real depth: 0.96

    Binding {
        target: root.parent
        property: "scale"
        value: root.pressed ? root.depth : 1
    }
}
