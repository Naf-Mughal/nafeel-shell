import QtQuick
import qs.config

// Ink spreading from a point to fill its parent's shape: a small drop at
// `origin` growing into the parent's full rounded rectangle as `p` goes 0 → 1
// (and drawing back to the point as it goes 1 → 0). It stays inside the
// parent the whole way, its corners rounding into the parent's at the end.
// A Surface's press (a ripple) and a toggle's fill (Chip, Tile) are this.
Rectangle {
    id: root

    property point origin: Qt.point(parent.width / 2, parent.height / 2)
    property real p: 0
    // The drop it starts as.
    property real drop: 8

    readonly property real w0: Math.min(drop * 2, parent.width)
    readonly property real h0: Math.min(drop * 2, parent.height)
    readonly property real x0: Math.max(0, Math.min(parent.width - w0, origin.x - w0 / 2))
    readonly property real y0: Math.max(0, Math.min(parent.height - h0, origin.y - h0 / 2))
    // The shape it fills to (the parent's radius unless said).
    property real r1: parent.radius ?? 0

    visible: p > 0.001
    x: x0 * (1 - p)
    y: y0 * (1 - p)
    width: w0 + (parent.width - w0) * p
    height: h0 + (parent.height - h0) * p
    radius: Math.min(width, height) / 2 + (Math.min(r1, Math.min(width, height) / 2) - Math.min(width, height) / 2) * p
}
