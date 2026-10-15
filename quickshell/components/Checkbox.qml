import QtQuick
import QtQuick.Shapes
import qs.config
import qs.services
import "keynav.js" as KeyNav

// A checkbox with an optional label (the whole row toggles). Checked, the
// box fills with ink spreading from its middle and a tick is brushed in,
// stroke by stroke; unchecked, the tick lifts and the ink draws back.
// Space or Enter toggles it from the keyboard.
//   Checkbox { text: "Show seconds"; checked: …; onToggled: … }
Item {
    id: root

    property bool checked
    property string text
    signal toggled

    // The fill and the tick: 0 → 1 as it's checked.
    property real fillP: checked ? 1 : 0
    property real tickP: checked ? 1 : 0
    Behavior on fillP {
        enabled: !Tokens.reduceMotion
        Anim {
            duration: Tokens.anim.fast
            easing.bezierCurve: Tokens.anim.emphasizedDecel
        }
    }
    Behavior on tickP {
        enabled: !Tokens.reduceMotion
        Anim {
            duration: Tokens.anim.normal
            easing.bezierCurve: Tokens.anim.emphasizedDecel
        }
    }

    readonly property real boxSize: 18
    readonly property bool hovered: hover.hovered

    implicitWidth: boxSize + (text !== "" ? Tokens.spacing.normal + label.implicitWidth : 0)
    implicitHeight: Math.max(boxSize, label.implicitHeight)

    property bool focusByKey: false
    activeFocusOnTab: true
    onActiveFocusChanged: {
        if (!activeFocus)
            focusByKey = false;
    }
    Keys.onPressed: event => {
        const k = event.key;
        if (k === Qt.Key_Space || k === Qt.Key_Return || k === Qt.Key_Enter)
            toggled();
        else if (k === Qt.Key_Down || k === Qt.Key_Tab)
            KeyNav.move(root, true);
        else if (k === Qt.Key_Up || k === Qt.Key_Backtab)
            KeyNav.move(root, false);
        else
            return;
        event.accepted = true;
    }

    StyledRect {
        id: box

        anchors.verticalCenter: parent.verticalCenter
        width: root.boxSize
        height: root.boxSize
        radius: Tokens.rounding.small
        color: "transparent"
        border.width: root.activeFocus && root.focusByKey ? 2 : 2 * (1 - root.fillP)
        border.color: root.activeFocus && root.focusByKey ? Colours.palette.m3primary : root.hovered ? Colours.palette.m3onSurface : Colours.palette.m3outline

        InkSpread {
            color: Colours.palette.m3primary
            p: root.fillP
            r1: box.radius
            drop: 3
        }

        // The tick, brushed in: the short stroke, then the long one.
        Shape {
            anchors.fill: parent
            visible: root.tickP > 0.01
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                id: tick

                // The tick's three points, in the box's 18 px.
                readonly property point a: Qt.point(4.2, 9.4)
                readonly property point b: Qt.point(7.6, 12.8)
                readonly property point c: Qt.point(13.8, 5.6)
                // How far along: the first 40% draws a→b, the rest b→c.
                readonly property real t1: Math.min(1, root.tickP / 0.4)
                readonly property real t2: Math.max(0, (root.tickP - 0.4) / 0.6)

                strokeColor: Colours.palette.m3onPrimary
                strokeWidth: 2.2
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                startX: a.x
                startY: a.y

                PathLine {
                    x: tick.a.x + (tick.b.x - tick.a.x) * tick.t1
                    y: tick.a.y + (tick.b.y - tick.a.y) * tick.t1
                }
                PathLine {
                    x: tick.b.x + (tick.c.x - tick.b.x) * tick.t2
                    y: tick.b.y + (tick.c.y - tick.b.y) * tick.t2
                }
            }
        }
    }

    StyledText {
        id: label

        visible: root.text !== ""
        anchors.left: box.right
        anchors.leftMargin: Tokens.spacing.normal
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: Colours.palette.m3onSurface
        font.pixelSize: Tokens.font.body
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: root.toggled()
    }
}
