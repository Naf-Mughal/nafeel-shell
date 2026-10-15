import QtQuick
import qs.config
import qs.services
import "written.js" as Written

// A heading: the Latin name in the serif, its Chinese gloss beside it in the
// CJK serif (Ryoku's Latin-names-it, gloss-seals-it pairing, in the xianxia
// voice: 声音 Sound, 传音 Notifications). With `writeOn`, the first time a
// heading is shown in a session it's written on: a brush sweeps across and
// the words appear behind it.
Item {
    id: root

    property string text
    property string gloss
    property int size: Tokens.font.title
    property color color: Colours.palette.m3onSurface
    property bool writeOn: false
    // How much is written: 0 none, 1 all.
    property real p: 1

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    function write(): void {
        const key = text + "|" + gloss;
        if (!writeOn || Tokens.reduceMotion || Written.seen[key])
            return;
        Written.seen[key] = true;
        stroke.restart();
    }

    onVisibleChanged: if (visible)
        write()
    Component.onCompleted: if (visible)
        write()

    NumberAnimation {
        id: stroke

        target: root
        property: "p"
        from: 0
        to: 1
        duration: Tokens.dur(620)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Tokens.anim.emphasizedDecel
    }

    Item {
        width: root.p < 1 ? row.implicitWidth * root.p : root.width
        height: root.height
        clip: root.p < 1

        Row {
            id: row

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
                // CJK glyphs sit visually smaller than Latin at the same size;
                // this matches the gloss to the title's cap height.
                font.pixelSize: Math.round(root.size * 1.05)
                font.letterSpacing: 1
                anchors.baseline: title.baseline
            }
        }
    }

    // The brush's tip, leading the words.
    Rectangle {
        visible: root.p > 0 && root.p < 1
        x: row.implicitWidth * root.p - width
        width: 12
        height: root.height
        opacity: Math.sin(root.p * Math.PI) * 0.55
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: "transparent"
            }
            GradientStop {
                position: 0.75
                color: Colours.palette.m3primary
            }
            GradientStop {
                position: 1
                color: "transparent"
            }
        }
    }
}
