import QtQuick
import qs.config
import qs.services

// A Material Symbols Rounded glyph (Caelestia's icon font), by ligature name:
// MaterialIcon { text: "wifi" }. `fill`: outlined (0) or filled (1). The
// variable font's axes are kept to whole steps: Qt makes a font engine (a
// FreeType face and its tables) for every distinct axis value, and an
// animated fill left dozens behind per icon size (ROADMAP O2).
StyledText {
    property real fill: 0
    property int size: 20
    property int grade: Colours.light ? 0 : -25

    font.family: "Material Symbols Rounded"
    font.pixelSize: size
    font.variableAxes: ({
            "FILL": fill >= 0.5 ? 1 : 0,
            "GRAD": grade,
            // The font's four designed optical sizes (20, 24, 40, 48dp),
            // the nearest for the size: every distinct value was a font
            // engine and glyph cache of its own (~15 MB in all, warm).
            "opsz": size <= 22 ? 20 : size <= 32 ? 24 : size <= 44 ? 40 : 48,
            "wght": 400
        })
    renderType: Text.QtRendering
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
