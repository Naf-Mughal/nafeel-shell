import QtQuick
import qs.services

// A window's part in the shell's ink transition (Ink): a still of
// `target` (by default everything in the window), shown over it while the
// change happens underneath, then soaked away by the ink front.
//
//   InkStill { target: someItem }      // or no target: the whole window
Item {
    id: root

    property Item target: parent
    // The tide line where ink meets paper.
    property color tide: Qt.alpha(Colours.palette.m3shadow, 0.55)

    anchors.fill: parent
    z: 100000

    ShaderEffectSource {
        id: still

        anchors.fill: parent
        sourceItem: root.target
        live: false
        recursive: true
        hideSource: false
        visible: false
    }

    Connections {
        target: Ink

        function onCapture(): void {
            still.scheduleUpdate();
        }
    }

    ShaderEffect {
        anchors.fill: parent
        // In the scene while the still is taken (clear: progress is 1 then)
        // so it renders, and while it shows.
        visible: Ink.frozen || Ink.capturing
        property var source: still
        property real progress: Ink.progress
        property point origin: Ink.origin
        property size size: Qt.size(width, height)
        // Frozen: the tide line keeps the old look's ink, not the new one's.
        property color tide: root.tide
        fragmentShader: Qt.resolvedUrl("../shaders/inkwipe.frag.qsb")
    }
}
