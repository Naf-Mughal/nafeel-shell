import QtQuick
import qs.config
import qs.services

// A line of recent values (oldest left), filled faintly below, scaled to
// `max` (or the largest value seen). Repaints when the values change.
//
//   Sparkline { values: SystemStats.cpuHistory; max: 1 }
Canvas {
    id: root

    property var values: []
    property real max: 0
    property color colour: Colours.palette.m3primary

    onValuesChanged: requestPaint()
    onColourChanged: requestPaint()
    onWidthChanged: requestPaint()

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
        ctx.beginPath();
        ctx.moveTo(x0, y(v[0]));
        for (let i = 1; i < v.length; i++)
            ctx.lineTo(x0 + i * step, y(v[i]));
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
