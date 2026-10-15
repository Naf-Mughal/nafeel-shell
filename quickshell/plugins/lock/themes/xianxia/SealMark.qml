import QtQuick
import QtQuick.Effects

// A seal on a card (the cultivator's face, a session's initial): a square
// at the shell's rounding (on "tight", a real seal's square corners), a
// double rule round it, the picture (`source`) or a letter.
Item {
    id: seal

    property real sc: 1
    property url source
    property string letter

    width: 62 * sc
    height: width

    readonly property real r: Math.min(width / 2, Xian.radiusMorph)

    Rectangle {
        id: shape

        anchors.fill: parent
        radius: seal.r
        visible: false
        layer.enabled: true
    }

    Rectangle {
        anchors.fill: parent
        radius: seal.r
        color: Xian.alpha(Xian.ink, 0.6)
        border.width: 1
        border.color: Xian.alpha(Xian.gold, 0.55)
    }

    Text {
        anchors.centerIn: parent
        visible: pic.status !== Image.Ready
        text: seal.letter
        font.family: Xian.serif
        font.pixelSize: 28 * seal.sc
        color: Xian.goldHi
    }

    Image {
        id: pic

        anchors.fill: parent
        source: seal.source
        sourceSize: Qt.size(width * 2, height * 2)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: pic
        visible: pic.status === Image.Ready
        maskEnabled: true
        maskSource: shape
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }

    // The inner rule.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 4 * seal.sc
        radius: Math.max(0, seal.r - 4 * seal.sc)
        color: "transparent"
        border.width: 1
        border.color: Xian.alpha(Xian.gold, 0.3)
    }
}
