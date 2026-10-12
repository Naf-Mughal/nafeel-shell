import QtQuick
import qs.config
import qs.services

// A heading: the Latin name in the serif, its Chinese gloss beside it in the
// CJK serif (Ryoku's Latin-names-it, gloss-seals-it pairing, in the xianxia
// voice: 声音 Sound, 传音 Notifications).
Row {
    id: root

    property string text
    property string gloss
    property int size: Tokens.font.title
    property color color: Colours.palette.m3onSurface

    spacing: Tokens.spacing.normal

    StyledText {
        id: title

        text: root.text
        color: root.color
        font.family: Tokens.font.serif
        font.pixelSize: root.size
        font.weight: Font.Medium
    }

    StyledText {
        visible: root.gloss !== ""
        text: root.gloss
        color: Colours.palette.m3primary
        opacity: 0.85
        font.family: Tokens.font.cjk
        // CJK glyphs sit visually smaller than Latin at the same size; this
        // matches the gloss to the title's cap height.
        font.pixelSize: Math.round(root.size * 1.05)
        font.letterSpacing: 1
        anchors.baseline: title.baseline
    }
}
