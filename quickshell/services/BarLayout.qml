pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.config

// Where every bar widget lives (ROADMAP Stage B). The frame has four edges,
// each with three regions (start, centre, end: start is the top of a
// vertical edge, the left of a horizontal one); a region is an ordered list
// of widget ids. Neighbours of one family share a capsule (Bar).
//
// Stored as the `bar.layout` setting:
//   { edges: { left: { start: [ids], center: [ids], end: [ids] }, top: …,
//              right: …, bottom: … } }
// An edge or region left out is empty. A plugin's widget that no region
// names goes where its manifest's slot puts it in the Default preset
// (bar.top / bar.actions: left start, bar.middle: left centre, bar.bottom:
// left end), unless `hidden` lists it.
Singleton {
    id: root

    readonly property var edgeNames: ["left", "top", "right", "bottom"]
    readonly property var regionNames: ["start", "center", "end"]

    // The kernel's widgets. `iconless` ones fit the thin strip (B2);
    // `popout` is the bar popout it opens.
    readonly property var kernelWidgets: ({
            clock: {
                name: "Clock",
                icon: "schedule",
                family: "clock",
                iconless: true
            },
            tray: {
                name: "Tray",
                icon: "apps",
                family: "tray"
            },
            sound: {
                name: "Sound",
                icon: "volume_up",
                family: "status",
                popout: "sound"
            },
            connect: {
                name: "Connections",
                icon: "wifi",
                family: "status",
                popout: "connect"
            },
            battery: {
                name: "Battery",
                icon: "battery_full",
                family: "status",
                popout: "battery"
            },
            power: {
                name: "Session",
                icon: "power_settings_new",
                family: "power",
                popout: "session"
            }
        })

    // Every widget there is: the kernel's and the enabled plugins'.
    readonly property var catalogue: {
        const out = Object.assign({}, kernelWidgets);
        for (const w of Plugins.barWidgets) {
            const pop = Object.keys(Plugins.popouts).find(k => Plugins.popouts[k].plugin === w.plugin);
            out[w.id] = {
                name: Plugins.all.find(p => p.id === w.plugin)?.name ?? w.id,
                icon: Plugins.all.find(p => p.id === w.plugin)?.icon ?? "extension",
                family: w.slot === "bar.actions" ? "actions" : w.plugin,
                url: w.url,
                slot: w.slot,
                popout: pop ?? ""
            };
        }
        return out;
    }

    // Today's desktop.
    readonly property var defaultLayout: ({
            edges: {
                left: {
                    start: ["workspaces", "notifications", "clipboard", "capture"],
                    center: ["clock"],
                    end: ["tray", "sound", "connect", "battery", "power"]
                }
            }
        })

    // What's set, over the Default preset (a layout that only hides an icon
    // or places a panel keeps Default's edges).
    readonly property var layout: {
        const set = Settings.values["bar.layout"] ?? {};
        return Object.assign({}, defaultLayout, set, {
            edges: set.edges ?? defaultLayout.edges
        });
    }

    // Widgets placed by the layout itself, and the plugin widgets it doesn't
    // name, by the region their slot gives them.
    readonly property var named: {
        const out = new Set();
        for (const e of edgeNames)
            for (const r of regionNames)
                for (const id of (layout.edges?.[e]?.[r] ?? []))
                    out.add(id);
        return out;
    }

    function slotRegion(slot: string): var {
        return slot === "bar.middle" ? ["left", "center"] : slot === "bar.bottom" ? ["left", "end"] : ["left", "start"];
    }

    // Whether a widget has anything to show right now (a battery, tray
    // icons); one that hasn't takes no room.
    function present(id: string): bool {
        if (id === "battery")
            return Power.hasBattery;
        if (id === "tray")
            return SystemTray.items.values.length > 0;
        return true;
    }

    // The widgets in a region, in order: ids that exist, aren't hidden and
    // have something to show.
    function widgets(edge: string, region: string): var {
        const hidden = layout.hidden ?? [];
        const ids = (layout.edges?.[edge]?.[region] ?? []).filter(id => !hidden.includes(id));
        for (const w of Plugins.barWidgets) {
            if (named.has(w.id) || hidden.includes(w.id))
                continue;
            const at = slotRegion(w.slot);
            if (at[0] === edge && at[1] === region)
                ids.push(w.id);
        }
        return ids.filter(id => catalogue[id] && present(id));
    }

    // Where a widget is: { edge, region }, or null.
    function placeOf(id: string): var {
        for (const e of edgeNames)
            for (const r of regionNames)
                if (widgets(e, r).includes(id))
                    return {
                        edge: e,
                        region: r
                    };
        return null;
    }

    // An edge with any widget on it is a bar.
    function used(edge: string): bool {
        return regionNames.some(r => widgets(edge, r).length > 0);
    }

    function iconic(id: string): bool {
        return !(catalogue[id]?.iconless ?? false);
    }

    // Whether a region (or any region of an edge) has an icon widget.
    function hasIcons(edge: string, region: string): bool {
        return (region ? [region] : regionNames).some(r => widgets(edge, r).some(id => iconic(id)));
    }

    // An edge's mode: "full" (the whole edge as thick as its thickest
    // region) or "regions" (the thin strip, with each region holding icon
    // widgets bulging out of it, as long as its content, like the dock).
    function mode(edge: string): string {
        return layout.edges?.[edge]?.mode ?? "full";
    }

    // The bar's thickness: a full bar's where it has icon widgets (icon-less
    // ones sit on the thin strip and don't grow it).
    function barThickness(edge: string): real {
        return hasIcons(edge, "") ? Tokens.barWidth : Tokens.border;
    }

    // The frame's thickness on an edge: the bar's in full mode, else the
    // strip (the bulges are drawn on top of it).
    function thickness(edge: string): real {
        return mode(edge) === "full" ? barThickness(edge) : Tokens.border;
    }

    // How a bar shows (`visibility` on the edge, `regionVisibility.<region>`
    // for a region in regions mode):
    //   "reserve"   always, and windows keep clear of it (full mode; a
    //               regions-mode bulge always sits over windows, like the dock)
    //   "overlay"   always, over windows
    //   "autohide"  the thin strip until hovered, while one of its popouts is
    //               open, or on an empty workspace
    function visibility(edge: string, region: string): string {
        const e = layout.edges?.[edge];
        const own = region ? e?.regionVisibility?.[region] : undefined;
        return own ?? e?.visibility ?? "reserve";
    }

    // The space windows keep clear of on an edge (umbriel's struts).
    function reserve(edge: string): real {
        return mode(edge) === "full" && visibility(edge, "") === "reserve" ? thickness(edge) : Tokens.border;
    }

    // The edges and regions meeting at each corner: [vertical, horizontal].
    readonly property var cornerEnds: ({
            topLeft: [["left", "start"], ["top", "start"]],
            topRight: [["right", "start"], ["top", "end"]],
            bottomLeft: [["left", "end"], ["bottom", "start"]],
            bottomRight: [["right", "end"], ["bottom", "end"]]
        })

    // Which bar runs through a corner: "vertical" (the side bar),
    // "horizontal" (the top or bottom one) or "none" (neither; the corner is
    // bare paper and both start after it). The one with something at that
    // end; when both have, the corner's setting (`corners.<corner>`, by
    // default the side bar's); when neither, the thicker.
    function cornerOwner(corner: string): string {
        const [v, h] = cornerEnds[corner];
        const hasV = widgets(v[0], v[1]).length > 0;
        const hasH = widgets(h[0], h[1]).length > 0;
        if (hasV && hasH)
            return layout.corners?.[corner] ?? "vertical";
        if (hasH)
            return "horizontal";
        if (hasV)
            return "vertical";
        return thickness(h[0]) > thickness(v[0]) ? "horizontal" : "vertical";
    }

    // Where an edge's bar runs along the edge, in screen coordinates: from
    // its start corner to its end one, through those it owns.
    function span(edge: string, width: real, height: real, t: var): var {
        const vertical = edge === "left" || edge === "right";
        if (vertical) {
            const top = cornerOwner(edge === "left" ? "topLeft" : "topRight") === "vertical" ? 0 : t.top;
            const bottom = cornerOwner(edge === "left" ? "bottomLeft" : "bottomRight") === "vertical" ? height : height - t.bottom;
            return [top, bottom];
        }
        const left = cornerOwner(edge === "top" ? "topLeft" : "bottomLeft") === "horizontal" ? 0 : t.left;
        const right = cornerOwner(edge === "top" ? "topRight" : "bottomRight") === "horizontal" ? width : width - t.right;
        return [left, right];
    }

    // ── Panels (ROADMAP B5) ──
    // A panel is a bar popout (named "bar:<kind>"), a plugin's drawer or the
    // kernel's (by name). A popout goes with its icon; one whose icon is
    // hidden, and any drawer, can be placed on its own (`panels.<name>`:
    // { edge, region } or { corner }).

    // Where a widget sits in the Default preset (or by its plugin slot).
    function defaultPlaceOf(id: string): var {
        for (const e of edgeNames)
            for (const r of regionNames)
                if ((defaultLayout.edges[e]?.[r] ?? []).includes(id))
                    return {
                        edge: e,
                        region: r
                    };
        const w = Plugins.barWidgets.find(x => x.id === id);
        if (!w)
            return null;
        const at = slotRegion(w.slot);
        return {
            edge: at[0],
            region: at[1]
        };
    }

    function iconOf(popout: string): string {
        return Object.keys(catalogue).find(k => catalogue[k].popout === popout) ?? "";
    }

    // A panel's place set in the layout, or null.
    function panelPlace(name: string): var {
        return layout.panels?.[name] ?? null;
    }

    // Where a bar popout is: its icon's place while the icon shows; else its
    // own place, or where its icon would be in the Default preset.
    function popoutPlace(popout: string): var {
        const id = iconOf(popout);
        return (id ? placeOf(id) : null) ?? panelPlace("bar:" + popout) ?? (id ? defaultPlaceOf(id) : null);
    }

    // A place as what grows out of it: a corner's name, or "edge:<edge>"
    // (a centre region's: a drawer out of the edge).
    function target(at: var): string {
        if (at.corner)
            return at.corner;
        if (at.region === "center")
            return "edge:" + at.edge;
        const end = at.region === "end";
        switch (at.edge) {
        case "left":
            return end ? "bottomLeft" : "topLeft";
        case "right":
            return end ? "bottomRight" : "topRight";
        case "top":
            return end ? "topRight" : "topLeft";
        default:
            return end ? "bottomRight" : "bottomLeft";
        }
    }

    // Whether two places are the same spot (one pill).
    function samePlace(a: var, b: var): bool {
        if (!a || !b)
            return false;
        return a.corner ? a.corner === b.corner : !b.corner && a.edge === b.edge && a.region === b.region;
    }

    // Whether the panel `name` (a drawer, or "bar:<kind>") sits where the
    // icon opening `popoutKey` ("bar:<kind>") is: then hovering that icon
    // switches to its panel, as on the dock.
    function sharesPill(name: string, popoutKey: string): bool {
        if (!popoutKey.startsWith("bar:"))
            return false;
        const there = popoutPlace(popoutKey.slice(4));
        const here = name.startsWith("bar:") ? popoutPlace(name.slice(4)) : panelPlace(name);
        return samePlace(here, there);
    }

    // Where a bar popout grows out of: the corner at its widget's end of the
    // edge, or for a centre widget "edge:<edge>" (a drawer out of the edge at
    // the widget).
    function cornerFor(popout: string): string {
        const at = popoutPlace(popout);
        if (!at)
            return Plugins.popouts[popout]?.corner ?? "topLeft";
        return target(at);
    }
}
