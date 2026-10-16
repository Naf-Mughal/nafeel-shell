import QtQuick
import qs.config
import qs.services

// Text whose changed characters roll like an odometer's: only the ones that
// differ move, up when the value went up, down when it went down. For values
// that change now and then (a volume, a brightness, a battery's %, a count),
// never for ones that change many times a second (a clock's seconds, live
// stats). Digits keep one width (tabular), so nothing jostles.
//   RollText { text: Math.round(volume * 100) + "%"; font.pixelSize: 15 }
//
// At rest it's one Text. The per-character roller (RollRoller: an Item, an
// animation and two Texts for every character, ~200 KB for "50%") is made
// while a change rolls and let go after: there were ~220 of them warm.
Item {
    id: root

    property string text
    property color color: Colours.palette.m3onSurface
    // No kerning or ligatures: the roller sets each character alone, so the
    // resting text has to lay out the same.
    property font font: Qt.font({
        family: Qt.application.font.family,
        pixelSize: Tokens.font.body,
        kerning: false,
        features: {
            tnum: 1,
            liga: 0,
            clig: 0,
            calt: 0
        }
    })
    // Which way this change rolls (the numbers in it compared).
    property bool up: true

    // What the resting text shows (the old text while a change rolls).
    property string _shown: ""
    property bool _ready: false
    property bool rolling: false

    implicitWidth: idle.implicitWidth
    implicitHeight: Math.round(font.pixelSize * 1.15)

    onTextChanged: {
        if (!_ready || Tokens.reduceMotion) {
            _shown = text;
            return;
        }
        if (text === _shown && !rolling)
            return;
        const a = parseFloat(_shown.replace(/[^0-9.\-]/g, "")), b = parseFloat(text.replace(/[^0-9.\-]/g, ""));
        if (!rolling)
            up = isNaN(a) || isNaN(b) || b >= a;
        rolling = true;
        settle.restart();
        if (roller.item)
            roller.item.text = text;
    }
    Component.onCompleted: {
        _shown = text;
        _ready = true;
    }

    // The roller is let go a moment after the last change.
    Timer {
        id: settle

        interval: Tokens.anim.normal + 120
        onTriggered: {
            root._shown = root.text;
            root.rolling = false;
        }
    }

    StyledText {
        id: idle

        y: (root.height - implicitHeight) / 2
        text: root.rolling ? root._shown : root.text
        color: root.color
        font: root.font
        opacity: root.rolling ? 0 : 1
    }

    Loader {
        id: roller

        active: root.rolling
        sourceComponent: RollRoller {
            color: root.color
            font: root.font
            up: root.up
        }
        // Starts from what was showing, then rolls to the new text.
        onLoaded: {
            item.text = root._shown;
            item.text = root.text;
        }
    }
}
