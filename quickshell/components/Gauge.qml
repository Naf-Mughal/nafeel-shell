import QtQuick
import qs.config
import qs.services

// An arc gauge (three quarters of a ring): `value` 0..1 in the role's ink
// over its track, the text inside. Warns in the error colour.
//
//   Gauge { value: SystemStats.cpu; text: "42%"; label: "CPU" }
Item {
    id: root

    property real value
    property string text
    property string label
    property bool warn
    property bool roll: false
    property real thickness: 10

    implicitWidth: 112
    implicitHeight: 112

    Canvas {
        id: canvas

        anchors.fill: parent

        property real shown: Math.max(0, Math.min(1, root.value))
        property color track: Colours.palette.m3secondaryContainer
        property color fill: root.warn ? Colours.palette.m3error : Colours.palette.m3primary

        Behavior on shown {
            Anim {}
        }

        onShownChanged: repaint()
        onTrackChanged: repaint()
        onFillChanged: repaint()
        onWidthChanged: repaint()
        // Painted only when it shows (Canvas paints on the CPU; warm panels
        // repainted their graphs with every sample, hidden): a change while
        // hidden is painted when it shows again.
        property bool _stale: false
        function repaint(): void {
            if (visible)
                requestPaint();
            else
                _stale = true;
        }
        onVisibleChanged: {
            if (visible && _stale) {
                _stale = false;
                requestPaint();
            }
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.lineWidth = root.thickness;
            ctx.lineCap = "round";
            const c = Math.min(width, height) / 2, r = c - root.thickness / 2 - 2;
            const start = Math.PI * 0.75, sweep = Math.PI * 1.5;
            ctx.strokeStyle = track;
            ctx.beginPath();
            ctx.arc(width / 2, height / 2, r, start, start + sweep);
            ctx.stroke();
            ctx.strokeStyle = fill;
            ctx.beginPath();
            ctx.arc(width / 2, height / 2, r, start, start + sweep * Math.max(0.001, shown));
            ctx.stroke();
        }
    }

    Column {
        anchors.centerIn: parent

        // Rolling where the value changes now and then (`roll`: a battery);
        // live stats (CPU every second or two) stay still.
        Loader {
            anchors.horizontalCenter: parent.horizontalCenter
            sourceComponent: root.roll ? rolling : still
        }

        MicroLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
        }
    }

    Component {
        id: still

        StyledText {
            text: root.text
            font.pixelSize: Tokens.font.value
            font.family: Tokens.font.mono
            color: Colours.palette.m3onSurface
        }
    }

    Component {
        id: rolling

        RollText {
            text: root.text
            font.pixelSize: Tokens.font.value
            font.family: Tokens.font.mono
            color: Colours.palette.m3onSurface
        }
    }
}
