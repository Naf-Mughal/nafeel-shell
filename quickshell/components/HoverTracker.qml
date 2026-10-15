import QtQuick

// Which of `items` (Surfaces) the pointer is on, for goo and hover-to-switch.
// It reads their own hover (where the pointer is on each) and moves only
// when the pointer itself moves (a panel resizing and sliding its items
// under a still pointer changes nothing: tabs ping-ponged), and only once
// the pointer is well inside an item, `deadZone` from its edges (at most a
// third of it): on an edge, or in a gap a moment, it stays put.
//   HoverTracker { id: hover; items: [...] }  … hover.current
QtObject {
    id: root

    property var items: []
    property real deadZone: 8
    property Item current: null
    property point _last: Qt.point(-999, -999)

    // Every item's hover and where on it (re-read as any of them changes).
    readonly property var _probe: items.map(it => it ? [it.hovered, it.hoverAt?.x ?? -1, it.hoverAt?.y ?? -1] : null)
    on_ProbeChanged: update()

    function update(): void {
        for (const it of items) {
            if (!it || !it.hovered || !it.visible)
                continue;
            const at = it.hoverAt;
            const sp = it.mapToItem(null, at.x, at.y);
            if (Math.abs(sp.x - _last.x) < 1 && Math.abs(sp.y - _last.y) < 1)
                return;
            _last = sp;
            away.stop();
            const dx = Math.min(deadZone, it.width / 3), dy = Math.min(deadZone, it.height / 3);
            if (at.x > dx && at.x < it.width - dx && at.y > dy && at.y < it.height - dy)
                current = it;
            return;
        }
        // On none: a gap a moment (stays), or gone (clears).
        away.restart();
    }

    property Timer away: Timer {
        interval: 200
        onTriggered: {
            root.current = null;
            root._last = Qt.point(-999, -999);
        }
    }
}
