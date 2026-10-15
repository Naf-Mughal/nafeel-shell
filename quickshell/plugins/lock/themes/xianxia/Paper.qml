import QtQuick

// A card on the shell's paper (its primitives' look, without the shell, so
// the login screen has it too): the panels' fill, translucent as the
// frosted-paper setting, with their ink wash and paper fibre (the frame's
// shader), at a card's rounding, with a hairline.
ShaderEffect {
    id: paper

    property real sc: 1
    property real radius: Xian.radiusNormal
    property color color: Xian.paperFill
    property real ink: Xian.paperInk
    property real fibre: Xian.paperFibre
    readonly property size size: Qt.size(width, height)
    property alias border: line.border

    fragmentShader: Qt.resolvedUrl("../../../../shaders/paper_sheet.frag.qsb")

    Rectangle {
        id: line

        anchors.fill: parent
        radius: paper.radius
        color: "transparent"
        border.width: 1
        border.color: Xian.alpha(Xian.paper, 0.08)
    }
}
