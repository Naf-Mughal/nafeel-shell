import QtQuick
import qs.config
import qs.services
import qs.components

// The shell's frame on the lock screen (the same shader, ink wash and gilded
// edge), so locking keeps the desktop's world around the screen. When the
// lock engages the bar's width retracts into a uniform border: the desktop
// flows into the lock instead of cutting to it.
ShaderEffect {
    id: root

    property bool engaged: false
    property real leftInset: engaged ? Tokens.border : Tokens.barWidth

    Behavior on leftInset {
        SpringAnimation {
            spring: Tokens.spring.gentle.spring
            damping: Tokens.spring.gentle.damping
            epsilon: 0.25
        }
    }

    property vector2d size: Qt.vector2d(width, height)
    property vector4d inset: Qt.vector4d(leftInset, Tokens.border, Tokens.border, Tokens.border)
    property real holeRadius: Tokens.frameRounding
    property real panelRadius: Tokens.rounding.large
    property real smoothing: Tokens.frameSmoothing
    property color color: Colours.tPalette.m3surface
    property vector4d p0
    property vector4d p1
    property vector4d p2
    property vector4d p3
    property vector4d p4
    property vector4d p5
    property vector4d p6
    property vector4d p7
    property vector4d p8
    property vector4d p9
    property vector4d d0: Qt.vector4d(1, 0, 1, 0)
    property vector4d d1: Qt.vector4d(1, 0, 1, 0)
    property vector4d d2: Qt.vector4d(1, 0, 1, 0)
    property vector4d d3: Qt.vector4d(1, 0, 1, 0)
    property vector4d d4: Qt.vector4d(1, 0, 1, 0)
    property vector4d d5: Qt.vector4d(1, 0, 1, 0)
    property vector4d d6: Qt.vector4d(1, 0, 1, 0)
    property vector4d d7: Qt.vector4d(1, 0, 1, 0)
    property vector4d d8: Qt.vector4d(1, 0, 1, 0)
    property vector4d d9: Qt.vector4d(1, 0, 1, 0)
    property color accent: Colours.palette.m3primary
    property real ink: Tokens.immersive ? 1 : 0.55
    property real gild: Tokens.immersive ? 0.4 : 0.25
    // Paper fibre (the paper texture setting).
    property real fibre: Tokens.paperTexture

    fragmentShader: Qt.resolvedUrl("../../shaders/frame.frag.qsb")

    Component.onCompleted: Qt.callLater(() => root.engaged = true)
}
