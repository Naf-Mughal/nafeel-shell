import QtQuick
import qs.config
import qs.services

// Drifting ink mist and rising spirit motes (shaders/mist.frag), for open
// drawers in fully immersive mode. It only animates while `running`.
ShaderEffect {
    id: root

    property bool running: visible
    property real time: 0

    property vector2d size: Qt.vector2d(width, height)
    property color mist: Colours.palette.m3onSurface
    property color mote: Colours.palette.m3primary
    property real strength: 1

    fragmentShader: Qt.resolvedUrl("../shaders/mist.frag.qsb")

    FrameAnimation {
        running: root.running && !Tokens.reduceMotion
        onTriggered: root.time += frameTime
    }
}
