import QtQuick
import qs.config
import qs.services

// A card of the frame's own paper: its colour (translucent as the frosted
// setting), ink wash and paper fibre, at a radius. Under a card's content
// where it stands alone on something that isn't the frame (the lock's
// player), so it reads as the same paper as the panels.
ShaderEffect {
    property real radius: Tokens.rounding.normal
    property color color: Colours.tPalette.m3surface
    property real ink: Tokens.immersive ? 1 : 0.55
    property real fibre: Tokens.paperTexture
    readonly property size size: Qt.size(width, height)

    fragmentShader: Qt.resolvedUrl("../shaders/paper_sheet.frag.qsb")
}
