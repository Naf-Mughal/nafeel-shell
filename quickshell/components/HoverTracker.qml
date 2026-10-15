import QtQuick

// Which of `items` the pointer is on, for goo and hover-to-switch: it
// changes only when the pointer itself moves (a panel resizing and sliding
// its items under a still pointer changes nothing: tabs ping-ponged), and
// only once the pointer is well inside an item, `deadZone` from its edges
// (at most a third of its size): on an edge or in a gap it stays put, so a
// boundary can't flick between two. Lay it over the items' area.
//   HoverTracker { id: hover; anchors.fill: parent; items: [...] }  … hover.current
Item {
    id: root

    property var items: []
    property real deadZone: 8
    property Item current: null
    property point _last: Qt.point(-999, -999)

    HoverHandler {
        id: handler

        onHoveredChanged: if (!hovered)
            root.current = null
        onPointChanged: {
            const sp = point.scenePosition;
            if (Math.abs(sp.x - root._last.x) < 1 && Math.abs(sp.y - root._last.y) < 1)
                return;
            root._last = sp;
            for (const it of root.items) {
                if (!it || !it.visible)
                    continue;
                const p = it.mapFromItem(root, point.position.x, point.position.y);
                const dx = Math.min(root.deadZone, it.width / 3), dy = Math.min(root.deadZone, it.height / 3);
                if (p.x > dx && p.x < it.width - dx && p.y > dy && p.y < it.height - dy) {
                    root.current = it;
                    return;
                }
            }
        }
    }
}
