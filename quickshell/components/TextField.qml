pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.config
import qs.services

// A filled M3 text field. `typing` picks how typing looks (the user chooses
// in the kit): "plain"; "ink", each new letter bleeds in like ink soaking
// into paper and a deleted one lifts away; "goo", the caret an ink drop that
// springs to its place, drawn out a little sideways as it goes; "brush", a
// brush stroke under the text that flows to the caret and pools there. A
// password with `seals` shows a seal pressed in per key instead of dots.
StyledRect {
    id: root

    property alias text: input.text
    property alias echoMode: input.echoMode
    property string placeholder
    // Optional: a function(event) that handles keys first (accept to stop).
    property var keyFilter: null
    property string typing: "plain"
    property bool seals: false
    signal accepted

    readonly property bool password: input.echoMode === TextInput.Password
    readonly property bool animate: !Tokens.reduceMotion

    function focusInput(): void {
        input.forceActiveFocus();
    }

    implicitHeight: 44
    radius: Tokens.rounding.small
    color: Colours.palette.m3surfaceContainerHighest
    border.width: input.activeFocus ? 2 : 0
    border.color: Colours.palette.m3primary

    TextInput {
        id: input

        // What it said a moment ago (ink: which letter came or went).
        property string was: ""

        anchors.fill: parent
        anchors.leftMargin: Tokens.spacing.normal
        anchors.rightMargin: Tokens.spacing.normal
        verticalAlignment: TextInput.AlignVCenter
        color: root.password && root.seals ? "transparent" : Colours.palette.m3onSurface
        selectionColor: Colours.palette.m3primary
        selectedTextColor: Colours.palette.m3onPrimary
        font.pixelSize: 13
        clip: true
        // Seals: no caret (the hidden text is narrower than the seals).
        cursorDelegate: root.password && root.seals ? noCaret : root.typing === "goo" && root.animate ? gooCaret : null
        onAccepted: root.accepted()
        Keys.onEscapePressed: ShellState.close()
        Keys.onPressed: event => {
            if (root.keyFilter)
                root.keyFilter(event);
        }
        onTextChanged: {
            if (root.typing === "ink" && root.animate && !(root.password && root.seals)) {
                if (text.length === was.length + 1 && cursorPosition > 0)
                    inkIn.createObject(input, {
                        at: cursorPosition - 1
                    });
                else if (text.length === was.length - 1)
                    inkOut.createObject(input, {
                        at: cursorPosition,
                        glyph: root.password ? passwordCharacter : was.charAt(cursorPosition)
                    });
            }
            was = text;
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            text: root.placeholder
            color: Colours.palette.m3onSurfaceVariant
            font.pixelSize: 13
        }
    }

    // ── ink: a new letter soaks in, a deleted one lifts away ──
    Component {
        id: inkIn

        Item {
            id: soak

            property int at
            readonly property rect r: input.positionToRectangle(at)
            readonly property real w: Math.max(4, input.positionToRectangle(at + 1).x - r.x)

            x: r.x
            y: r.y
            width: w
            height: r.height

            // The bloom under the letter, spreading and fading.
            Rectangle {
                anchors.centerIn: parent
                width: soak.height * 0.9
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

            // The paper over the letter, lifting: the letter appears through it.
            Rectangle {
                anchors.fill: parent
                color: root.color

                NumberAnimation on opacity {
                    from: 1
                    to: 0
                    duration: Tokens.anim.fast
                    easing.type: Easing.OutQuad
                    onFinished: destroyTimer.start()
                }
            }

            Timer {
                id: destroyTimer

                interval: Tokens.anim.normal
                onTriggered: soak.destroy()
            }
        }
    }

    Component {
        id: inkOut

        StyledText {
            id: lift

            property int at
            property string glyph
            readonly property rect r: input.positionToRectangle(at)

            x: r.x
            y: r.y + (r.height - implicitHeight) / 2
            text: glyph
            color: Colours.palette.m3onSurface
            font.pixelSize: 13

            ParallelAnimation {
                running: true
                onFinished: lift.destroy()

                NumberAnimation {
                    target: lift
                    property: "opacity"
                    from: 0.8
                    to: 0
                    duration: Tokens.anim.normal
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: lift
                    property: "y"
                    to: lift.y - 6
                    duration: Tokens.anim.normal
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: lift
                    property: "scale"
                    to: 1.25
                    duration: Tokens.anim.normal
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    Component {
        id: noCaret

        Item {}
    }

    // ── goo: the caret, an ink drop that springs to its place ──
    Component {
        id: gooCaret

        Item {
            id: caret

            // Where the drop is (springing after where the caret is).
            property real sx: x
            readonly property real lag: x - sx

            width: 2
            visible: input.cursorVisible

            Behavior on sx {
                SpringAnimation {
                    spring: Tokens.springK(5)
                    damping: Tokens.dampK(0.42)
                    epsilon: 0.2
                }
            }

            Rectangle {
                // Drawn out sideways along its travel (no tilt), then round.
                readonly property real stretch: Math.min(16, Math.abs(caret.lag) * 0.45)

                // At the drop (behind the caret), reaching toward the caret.
                x: caret.lag > 0 ? -caret.lag : -caret.lag - stretch
                y: 2
                width: 3 + stretch
                height: caret.height - 4
                radius: 1.5
                color: Colours.palette.m3primary
            }
        }
    }

    // ── brush: a stroke under the text that flows to the caret ──
    Shape {
        id: brush

        // The caret's place along the field (springing), and how far the
        // stroke has come out (on focus).
        property real tip: input.x + input.cursorRectangle.x
        property real reach: input.activeFocus ? 1 : 0

        visible: root.typing === "brush" && reach > 0.01
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 5
        height: 6
        preferredRendererType: Shape.CurveRenderer

        Behavior on tip {
            enabled: root.animate
            SpringAnimation {
                spring: Tokens.springK(4)
                damping: Tokens.dampK(0.4)
                epsilon: 0.3
            }
        }
        Behavior on reach {
            Anim {
                duration: Tokens.anim.normal
            }
        }

        ShapePath {
            id: stroke

            readonly property real x0: input.x
            readonly property real x1: x0 + (Math.max(x0 + 6, brush.tip) - x0) * brush.reach

            fillColor: Colours.palette.m3primary
            strokeWidth: -1
            // A hairline at the start, thickening to the caret, pooling there.
            startX: x0
            startY: 3

            PathLine {
                x: stroke.x1 - 3
                y: 1
            }
            PathArc {
                x: stroke.x1 - 3
                y: 5
                radiusX: 2.5
                radiusY: 2
                useLargeArc: true
            }
            PathLine {
                x: stroke.x0
                y: 3.5
            }
        }
    }

    // ── seals: a password as seals pressed in, one per key ──
    Row {
        visible: root.password && root.seals
        anchors.left: parent.left
        anchors.leftMargin: Tokens.spacing.normal
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Repeater {
            model: root.password && root.seals ? input.text.length : 0

            Rectangle {
                id: seal

                required property int index

                width: 11
                height: 11
                radius: 2
                // Cinnabar never themes (components/Seal).
                color: "#c8372d"
                rotation: index % 2 ? 4 : -5
                scale: root.animate ? 1.6 : 1
                opacity: root.animate ? 0 : 1

                Rectangle {
                    anchors.centerIn: parent
                    width: 4
                    height: 4
                    radius: 1
                    color: Qt.alpha("#f3e6cf", 0.85)
                }

                Component.onCompleted: if (root.animate)
                    press.start()

                ParallelAnimation {
                    id: press

                    NumberAnimation {
                        target: seal
                        property: "scale"
                        to: 1
                        duration: Tokens.anim.fast
                        easing.type: Easing.OutBack
                        easing.overshoot: 2
                    }
                    NumberAnimation {
                        target: seal
                        property: "opacity"
                        to: 1
                        duration: Tokens.anim.hover
                    }
                }
            }
        }
    }
}
