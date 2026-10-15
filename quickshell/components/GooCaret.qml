import QtQuick
import qs.config
import qs.services

// The goo caret (a text item's cursorDelegate, TextInput or TextEdit): an ink
// drop that springs to the caret's place, drawn out sideways along its way
// (no tilt), round again when it lands. The text item places this delegate
// at the caret; the drop lags behind it on a spring.
//   TextInput { cursorDelegate: Component { GooCaret {} } }
Item {
    id: caret

    // Where the drop is, springing after where the caret is.
    property real sx: x
    property real sy: y
    readonly property real lag: x - sx
    readonly property real lagY: y - sy

    width: 2
    visible: parent?.cursorVisible ?? true

    Behavior on sx {
        enabled: !Tokens.reduceMotion
        SpringAnimation {
            spring: Tokens.spring.control.spring
            damping: Tokens.spring.control.damping
            epsilon: 0.2
        }
    }
    Behavior on sy {
        enabled: !Tokens.reduceMotion
        SpringAnimation {
            spring: Tokens.spring.control.spring
            damping: Tokens.spring.control.damping
            epsilon: 0.2
        }
    }

    Rectangle {
        // Drawn out along its travel, toward the caret.
        readonly property real stretch: Math.min(16, Math.abs(caret.lag) * 0.45)

        x: caret.lag > 0 ? -caret.lag : -caret.lag - stretch
        y: 2 - caret.lagY
        width: 3 + stretch
        height: caret.height - 4
        radius: 1.5
        color: Colours.palette.m3primary
    }
}
