import QtQuick
import qs.config
import qs.services

// A cinnabar seal stamp with a character pressed into it (the xianxia mark,
// like Ryoku's 力): a slightly rotated square, the glyph in the paper colour.
// Cinnabar is fixed, never themed: a seal is a seal on any wallpaper.
StyledRect {
    id: root

    property string glyph: "印"
    property int size: 22
    readonly property color cinnabar: "#c8372d"

    implicitWidth: size
    implicitHeight: size
    radius: Math.min(Tokens.rounding.small, size / 5)
    rotation: -4
    color: cinnabar
    antialiasing: true

    StyledText {
        anchors.centerIn: parent
        text: root.glyph
        color: "#f3e7cf"
        font.family: Tokens.font.cjk
        font.pixelSize: Math.round(root.size * 0.62)
        font.weight: Font.Bold
    }
}
