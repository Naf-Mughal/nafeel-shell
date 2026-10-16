pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// The per-character roller behind RollText: an Item and two Texts a
// character, built only while a change is animating (RollText), and let go
// after. Only the characters that differ move, up when the value went up,
// down when it went down. Digits keep one width (tabular), so nothing
// jostles.
Row {
    id: root

    property string text
    property color color: Colours.palette.m3onSurface
    property font font: Qt.font({
        family: Qt.application.font.family,
        pixelSize: Tokens.font.body,
        features: {
            tnum: 1
        }
    })
    // Which way this change rolls (the numbers in it compared).
    property bool up: true
    property string _was: ""

    onTextChanged: {
        const a = parseFloat(_was.replace(/[^0-9.\-]/g, "")), b = parseFloat(text.replace(/[^0-9.\-]/g, ""));
        up = isNaN(a) || isNaN(b) || b >= a;
        _was = text;
        for (let i = 0; i < text.length; i++) {
            if (i < chars.count) {
                if (chars.get(i).ch !== text[i])
                    chars.setProperty(i, "ch", text[i]);
            } else {
                chars.append({
                    ch: text[i]
                });
            }
        }
        while (chars.count > text.length)
            chars.remove(chars.count - 1);
    }
    // The first text may already have come through onTextChanged (a binding
    // set while it's made): fill only what isn't there.
    Component.onCompleted: {
        _was = text;
        for (let i = chars.count; i < text.length; i++)
            chars.append({
                ch: text[i]
            });
    }

    ListModel {
        id: chars
    }

    Repeater {
        model: chars

        Item {
            id: slot

            required property string ch
            // What it showed before this change, and how far the roll is.
            property string from: ""
            property real p: 1
            property bool up: true

            // A window the glyphs' height (the line box is taller: the old
            // digit would linger in view above the new one).
            readonly property real base: (height - now.implicitHeight) / 2
            width: now.implicitWidth
            height: Math.round(root.font.pixelSize * 1.15)
            clip: true

            onChChanged: {
                if (Tokens.reduceMotion) {
                    now.text = ch;
                    return;
                }
                from = now.text === ch ? from : now.text;
                up = root.up;
                roll.restart();
            }
            Component.onCompleted: now.text = ch

            NumberAnimation {
                id: roll

                target: slot
                property: "p"
                from: 0
                to: 1
                duration: Tokens.anim.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.anim.emphasizedDecel
                onStarted: now.text = slot.ch
            }

            StyledText {
                id: now

                y: slot.base + (1 - slot.p) * slot.height * (slot.up ? 1 : -1)
                color: root.color
                font: root.font
            }

            StyledText {
                visible: slot.p < 1
                y: slot.base - slot.p * slot.height * (slot.up ? 1 : -1)
                opacity: 1 - slot.p
                color: root.color
                font: root.font
                text: slot.from
            }
        }
    }
}
