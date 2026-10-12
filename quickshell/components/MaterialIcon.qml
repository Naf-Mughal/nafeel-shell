import QtQuick
import qs.config
import qs.services

// A Material Symbols Rounded glyph (Caelestia's icon font), by ligature name:
// MaterialIcon { text: "wifi" }. `fill` (0..1) animates outlined -> filled.
StyledText {
    property real fill: 0
    property int size: 20
    property int grade: Colours.light ? 0 : -25

    font.family: "Material Symbols Rounded"
    font.pixelSize: size
    font.variableAxes: ({
            "FILL": fill,
            "GRAD": grade,
            "opsz": Math.max(20, Math.min(48, size)),
            "wght": 400
        })
    renderType: Text.QtRendering
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    Behavior on fill {
        Anim {
            duration: Tokens.dur(200)
        }
    }
}
