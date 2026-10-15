pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// Ink typing for a text item (TextInput or TextEdit; this sits inside it): a
// new letter soaks in, with a bloom spreading under it and the paper over it
// lifting; a deleted one lifts away and fades. One letter at a time (a paste
// or a cut just appears).
//   TextInput { id: t; TypingInk { target: t; paper: field.color } }
Item {
    id: root

    required property Item target
    // The colour under the text (the paper that lifts off a new letter).
    property color paper: Colours.palette.m3surfaceContainerHighest
    // What a deleted letter shows as (a password's mask).
    property string mask: ""
    property string was: ""

    anchors.fill: parent

    Connections {
        target: root.target

        function onTextChanged(): void {
            const t = root.target.text, c = root.target.cursorPosition;
            if (root.enabled && !Tokens.reduceMotion) {
                if (t.length === root.was.length + 1 && c > 0)
                    soak.createObject(root, {
                        at: c - 1
                    });
                else if (t.length === root.was.length - 1)
                    lift.createObject(root, {
                        at: c,
                        glyph: root.mask || root.was.charAt(c)
                    });
            }
            root.was = t;
        }
    }

    Component {
        id: soak

        Item {
            id: s

            property int at
            readonly property rect r: root.target.positionToRectangle(at)
            readonly property rect next: root.target.positionToRectangle(at + 1)

            x: r.x
            y: r.y
            // The letter's width (to the next one on the same line).
            width: next.y === r.y ? Math.max(4, next.x - r.x) : 8
            height: r.height

            // The bloom under the letter, spreading and fading.
            Rectangle {
                anchors.centerIn: parent
                width: s.height * 0.9
                height: width
                radius: width / 2
                color: Colours.palette.m3primary
                opacity: 0
                scale: 0.4

                SequentialAnimation on opacity {
                    NumberAnimation {
                        to: 0.28
                        duration: Tokens.anim.hover
                    }
                    NumberAnimation {
                        to: 0
                        duration: Tokens.anim.normal
                        easing.type: Easing.OutCubic
                    }
                }
                NumberAnimation on scale {
                    to: 1.5
                    duration: Tokens.anim.normal + Tokens.anim.hover
                    easing.type: Easing.OutCubic
                }
            }

            // The paper over the letter, lifting: the letter shows through.
            Rectangle {
                anchors.fill: parent
                color: root.paper

                NumberAnimation on opacity {
                    from: 1
                    to: 0
                    duration: Tokens.anim.fast
                    easing.type: Easing.OutQuad
                }
            }

            Timer {
                running: true
                interval: Tokens.anim.normal + Tokens.anim.hover + 20
                onTriggered: s.destroy()
            }
        }
    }

    Component {
        id: lift

        StyledText {
            id: l

            property int at
            property string glyph
            readonly property rect r: root.target.positionToRectangle(at)

            x: r.x
            y: r.y + (r.height - implicitHeight) / 2
            text: glyph
            color: root.target.color.a > 0 ? root.target.color : Colours.palette.m3onSurface
            font: root.target.font

            ParallelAnimation {
                running: true
                onFinished: l.destroy()

                NumberAnimation {
                    target: l
                    property: "opacity"
                    from: 0.8
                    to: 0
                    duration: Tokens.anim.normal
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: l
                    property: "y"
                    to: l.y - 6
                    duration: Tokens.anim.normal
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: l
                    property: "scale"
                    to: 1.25
                    duration: Tokens.anim.normal
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
