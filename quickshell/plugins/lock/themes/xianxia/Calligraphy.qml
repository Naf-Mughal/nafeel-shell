import QtQuick
import "../.."

// A vertical column of calligraphy written in: each character inks in after
// the one above (from a little larger, settling as it dries), at its own
// writing pace once `go` (the surface's UI showing); changed text writes in
// again.
Column {
    id: col

    property string text
    property real sc: 1
    property bool go: true
    property real p: 0

    onGoChanged: if (go)
        write.restart()
    onTextChanged: if (go)
        write.restart()
    Component.onCompleted: if (go)
        write.restart()

    NumberAnimation {
        id: write

        target: col
        property: "p"
        from: 0
        to: 1
        duration: Xian.d(1600)
    }
    property color color: Xian.paper

    spacing: 1.5 * sc

    Repeater {
        model: col.text.split("")

        Text {
            required property int index
            required property string modelData
            readonly property int count: Math.max(1, col.text.length)
            readonly property real start: index / count * 0.55
            readonly property real a: LockTheme.seg(col.p, start, start + 0.45)

            text: modelData
            font.family: Xian.cjk
            font.weight: Font.Black
            font.pixelSize: 30 * col.sc
            color: col.color
            opacity: a
            scale: 1.35 - 0.35 * a
            transform: Translate {
                y: (1 - a) * -6 * col.sc
            }
        }
    }
}
