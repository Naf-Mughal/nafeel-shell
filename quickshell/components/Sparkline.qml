import QtQuick
import qs.config
import qs.services

// A smooth line of recent values (oldest left), filled faintly below, scaled to
// `max` (or the largest value seen). Repaints when the values change.
//
//   Sparkline { values: SystemStats.cpuHistory; max: 1 }
Canvas {
    id: root

    property var values: []
    property real max: 0
    property color colour: Colours.palette.m3primary

    onValuesChanged: repaint()
    onColourChanged: repaint()
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
        const v = values ?? [];
        if (v.length < 2)
            return;
        const top = max > 0 ? max : Math.max(1, ...v);
        const step = width / 59;
        const x0 = width - (v.length - 1) * step;
        const y = val => height - 2 - (height - 4) * Math.min(1, val / top);
        // A smooth curve through the values (each bend at the midpoint
        // between two, the values as its control points), not a zigzag.
        ctx.beginPath();
        ctx.moveTo(x0, y(v[0]));
        for (let i = 1; i < v.length - 1; i++) {
            const mx = x0 + (i + 0.5) * step, my = (y(v[i]) + y(v[i + 1])) / 2;
            ctx.quadraticCurveTo(x0 + i * step, y(v[i]), mx, my);
        }
        ctx.lineTo(x0 + (v.length - 1) * step, y(v[v.length - 1]));
        ctx.lineWidth = 2;
        ctx.lineJoin = "round";
        ctx.strokeStyle = colour;
        ctx.stroke();
        ctx.lineTo(x0 + (v.length - 1) * step, height);
        ctx.lineTo(x0, height);
        ctx.closePath();
        ctx.fillStyle = Qt.alpha(colour, 0.14);
        ctx.fill();
    }
}
