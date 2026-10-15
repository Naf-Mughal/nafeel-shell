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
    hovered: {
        for (const r of rows)
            if (r.hovered)
                return r;
        return null;
    }
    fill: Colours.roleFill("secondary", "soft", 0)
    radius: Tokens.rounding.normal
}
