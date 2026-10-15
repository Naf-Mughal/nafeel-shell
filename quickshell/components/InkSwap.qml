import QtQuick
import qs.config
import qs.services

// A label whose text, when it changes, is brushed over: a soft ink edge
// sweeps across, the new text showing behind it and the old one ahead of
// it. For labels that switch now and then (Off → On, a track's name, a
// tab's title); never for text that changes many times a second.
//   InkSwap { text: on ? "On" : "Off"; font.pixelSize: 12 }
Item {
    id: root

    property string text
    property color color: Colours.palette.m3onSurface
    property alias font: now.font
    property alias horizontalAlignment: now.horizontalAlignment
    property alias elide: now.elide
    // The brush's edge: 0 at the start, 1 past the end.
    property real p: 1
    property string _was: ""

    implicitWidth: Math.max(now.implicitWidth, p < 1 ? old.implicitWidth : 0)
    implicitHeight: now.implicitHeight

    onTextChanged: {
        if (!Tokens.reduceMotion && _was !== "" && _was !== text) {
            old.text = _was;
            sweep.restart();
        }
        _was = text;
    }
    Component.onCompleted: _was = text

    // Where the edge is, across the wider of the two texts and its softness.
    readonly property real span: Math.max(now.implicitWidth, old.implicitWidth) + edge.width
    readonly property real at: p * span

    NumberAnimation {
        id: sweep

        target: root
        property: "p"
        from: 0
        to: 1
        duration: Tokens.anim.normal + Tokens.anim.hover
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Tokens.anim.standard
    }

    // The new text, shown behind the edge.
    Item {
        width: root.p < 1 ? Math.max(0, root.at - edge.width / 2) : root.width
        height: root.height
        clip: root.p < 1

        StyledText {
            id: now

            width: root.width
            text: root.text
            color: root.color
        }
    }

    // The old text, ahead of the edge.
    Item {
        visible: root.p < 1
        x: Math.max(0, root.at - edge.width / 2)
        width: Math.max(0, root.width - x)
        height: root.height
        clip: true

        StyledText {
            id: old

            x: -parent.x
            width: root.width
            color: root.color
            font: now.font
            horizontalAlignment: now.horizontalAlignment
            elide: now.elide
        }
    }

    // The brush's edge: a soft stroke of ink sweeping across.
    Rectangle {
        id: edge

        visible: root.p > 0 && root.p < 1
        x: root.at - width
        width: 10
        height: root.height
        opacity: Math.sin(root.p * Math.PI) * 0.6
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: "transparent"
            }
            GradientStop {
                position: 0.7
                color: Colours.palette.m3primary
            }
            GradientStop {
                position: 1
                color: "transparent"
            }
        }
    }
}
