import QtQuick
import qs.config
import qs.services

// The goo for a list: one blob resting on the picked row, following the
// hovered one (GooIndicator). Lay it under the rows' container (a Column, or
// a ListView's contentItem); rows take part by pointing at it (ListRow
// `goo: theGoo; picked: …`), and read their ink from `covers(row)`.
//   ListGoo { id: goo; anchors.fill: rows; container: rows }
//   Column { id: rows; Repeater { ListRow { goo: goo; picked: … } } }
GooIndicator {
    id: root

    required property Item container
    // Only hover (a list where several rows can be on at once).
    property bool hoverOnly: false

    // The rows that take part, read again as rows come and go or change:
    // the container's children, or theirs (a row in an entry with more
    // under it, a network's password).
    readonly property var rows: {
        const out = [];
        const kids = container?.children ?? [];
        for (let i = 0; i < kids.length; i++) {
            const k = kids[i];
            if (k.goo === root) {
                if (k.visible)
                    out.push(k);
                continue;
            }
            const sub = k.children ?? [];
            for (let j = 0; j < sub.length; j++)
                if (sub[j].goo === root && sub[j].visible)
                    out.push(sub[j]);
        }
        return out;
    }

    selected: {
        if (hoverOnly)
            return null;
        for (const r of rows)
            if (r.picked)
                return r;
        return null;
    }
    // The hover with dead zones, the pointer's own moves only (a list
    // sliding under a still pointer doesn't move it).
    hovered: tracker.current

    // Beside the container, over its area (inside, a Column would lay it
    // out as a row; a list's content moves it with the scroll).
    HoverTracker {
        id: tracker

        parent: root.container?.parent ?? null
        x: root.container?.x ?? 0
        y: root.container?.y ?? 0
        width: root.container?.width ?? 0
        height: root.container?.height ?? 0
        items: root.rows
    }
    fill: Colours.roleFill("secondary", "soft", 0)
    radius: Tokens.rounding.normal
}
