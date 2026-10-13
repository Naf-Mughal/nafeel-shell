pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
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

    // Settings → Bar: the studio (modules/settings/BarStudio.qml).
    readonly property SettingsPage settings: SettingsPage {
        name: "bar"
        title: "Bar"
        gloss: "栏"
        icon: "view_quilt"
        order: 11
        description: "Where every icon and panel lives, and how each bar shows."
        content: Qt.resolvedUrl("../modules/settings/BarStudio.qml")
    }

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

    // The studio's unsaved edit (Settings → Bar): the desktop follows it
    // live; save() keeps it, revert() (or closing the studio) walks back.
    property var draft: null
    readonly property bool dirty: draft !== null

    // What's set (or being edited), over the Default preset (a layout that
    // only hides an icon or places a panel keeps Default's edges).
    readonly property var layout: {
        const set = draft ?? Settings.values["bar.layout"] ?? {};
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

    // Whether a widget needs a full bar's thickness on an edge: an icon
    // anywhere; a text widget (the clock) down a side bar, where it stacks.
    function needsBar(id: string, edge: string): bool {
        return iconic(id) || edge === "left" || edge === "right";
    }

    // Whether a region (or any region of an edge) needs a bar's thickness:
    // its pill.
    function hasIcons(edge: string, region: string): bool {
        return (region ? [region] : regionNames).some(r => widgets(edge, r).some(id => needsBar(id, edge)));
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

    // How a bar shows (`visibility` on the edge):
    //   "reserve"   always, and windows keep clear of the bar's whole
    //               thickness (in regions mode too: it's still a bar)
    //   "overlay"   always, over windows
    //   "autohide"  the thin strip until hovered, while one of its popouts is
    //               open, or on an empty workspace
    // A region (regions mode) goes with its bar, except on an overlay bar,
    // where each can be shown ("overlay") or autohidden
    // (`regionVisibility.<region>`).
    function visibility(edge: string, region: string): string {
        const e = layout.edges?.[edge];
        const bar = e?.visibility ?? "reserve";
        if (region && bar === "overlay")
            return e?.regionVisibility?.[region] === "autohide" ? "autohide" : "overlay";
        return bar;
    }

    // The space windows keep clear of on an edge (umbriel's struts): a
    // reserved bar's thickness, else the strip.
    function reserve(edge: string): real {
        return visibility(edge, "") === "reserve" ? barThickness(edge) : Tokens.border;
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

    // ── Editing (the studio) ──

    // A region's ids as stored, with the plugin widgets it gets by default
    // (nothing filtered: hidden, absent battery or empty tray included).
    function rawWidgets(edge: string, region: string): var {
        const ids = (layout.edges?.[edge]?.[region] ?? []).slice();
        for (const w of Plugins.barWidgets) {
            if (named.has(w.id))
                continue;
            const at = slotRegion(w.slot);
            if (at[0] === edge && at[1] === region)
                ids.push(w.id);
        }
        return ids.filter(id => catalogue[id]);
    }

    // The layout written out in full (every edge and region listed), to
    // edit.
    function materialize(): var {
        const out = JSON.parse(JSON.stringify(layout));
        const edges = {};
        for (const e of edgeNames) {
            const old = out.edges?.[e] ?? {};
            edges[e] = Object.assign({}, old);
            for (const r of regionNames)
                edges[e][r] = rawWidgets(e, r);
        }
        out.edges = edges;
        out.hidden = out.hidden ?? [];
        out.panels = out.panels ?? {};
        out.corners = out.corners ?? {};
        return out;
    }

    function edit(change: var): void {
        const next = materialize();
        change(next);
        draft = next;
    }

    function save(): void {
        if (draft === null)
            return;
        Settings.set("bar.layout", draft);
        draft = null;
    }

    function revert(): void {
        draft = null;
    }

    // A preset as the draft ("default" goes back to Default).
    function usePreset(name: string): void {
        const p = presets[name];
        if (p)
            draft = JSON.parse(JSON.stringify(p));
    }

    // Put a widget in a region (before `before`, else last); it's shown.
    function moveWidget(id: string, edge: string, region: string, before: string): void {
        edit(l => {
            for (const e of edgeNames)
                for (const r of regionNames)
                    l.edges[e][r] = l.edges[e][r].filter(x => x !== id);
            l.hidden = l.hidden.filter(x => x !== id);
            const list = l.edges[edge][region];
            const i = before ? list.indexOf(before) : -1;
            list.splice(i < 0 ? list.length : i, 0, id);
            // An icon shown again takes its panel back with it.
            const pop = catalogue[id]?.popout;
            if (pop)
                delete l.panels["bar:" + pop];
        });
    }

    // Hide a widget's icon; its panel stays where the icon was until placed.
    function hideWidget(id: string): void {
        const at = placeOf(id);
        edit(l => {
            for (const e of edgeNames)
                for (const r of regionNames)
                    l.edges[e][r] = l.edges[e][r].filter(x => x !== id);
            if (!l.hidden.includes(id))
                l.hidden.push(id);
            const pop = catalogue[id]?.popout;
            if (pop && at && !l.panels["bar:" + pop])
                l.panels["bar:" + pop] = at;
        });
    }

    // Place a panel: { edge, region } or { corner }; null puts it back where
    // it opens by default.
    function placePanel(name: string, at: var): void {
        edit(l => {
            if (at)
                l.panels[name] = at;
            else
                delete l.panels[name];
        });
    }

    function setEdge(edge: string, key: string, value: var): void {
        edit(l => l.edges[edge][key] = value);
    }

    function setRegionVisibility(edge: string, region: string, value: string): void {
        edit(l => {
            const rv = Object.assign({}, l.edges[edge].regionVisibility ?? {});
            rv[region] = value;
            l.edges[edge].regionVisibility = rv;
        });
    }

    function setCorner(corner: string, value: string): void {
        edit(l => l.corners[corner] = value);
    }

    // Ready-made layouts.
    readonly property var presets: ({
            default: {},
            top: {
                edges: {
                    top: {
                        start: ["workspaces"],
                        center: ["clock"],
                        end: ["notifications", "clipboard", "capture", "tray", "sound", "connect", "battery", "power"]
                    }
                }
            },
            floating: {
                edges: {
                    left: {
                        mode: "regions",
                        start: ["workspaces", "notifications", "clipboard", "capture"],
                        end: ["tray", "sound", "connect", "battery", "power"]
                    },
                    top: {
                        center: ["clock"]
                    }
                }
            },
            hidden: {
                edges: {
                    left: {
                        visibility: "autohide",
                        start: ["workspaces", "notifications", "clipboard", "capture"],
                        center: ["clock"],
                        end: ["tray", "sound", "connect", "battery", "power"]
                    }
                }
            }
        })

    // The panels the studio can place: the plugins' drawers and Settings
    // ([{ name, label, icon }]; a bar popout is placed with its icon, or on
    // its own once the icon is hidden).
    readonly property var panelList: Plugins.drawers.map(d => ({
                name: d.name,
                label: Plugins.all.find(p => p.id === d.plugin)?.name + (d.name !== d.plugin ? ` · ${d.name}` : ""),
                icon: Plugins.all.find(p => p.id === d.plugin)?.icon ?? "web_asset",
                def: d
            })).concat([{
                name: "settings",
                label: "Settings",
                icon: "tune",
                def: {
                    edge: "top",
                    along: 0.5
                }
            }])

    // Where a panel opens now, as a place (its layout place, else derived
    // from its manifest; a bar popout's from its icon).
    function panelAt(name: string): var {
        if (name.startsWith("bar:"))
            return popoutPlace(name.slice(4));
        const set = panelPlace(name);
        if (set)
            return set;
        const d = panelList.find(p => p.name === name)?.def;
        if (!d)
            return null;
        return d.edge === "corner" ? {
            corner: d.corner
        } : {
            edge: d.edge ?? "top",
            region: (d.along ?? 0.5) < 0.34 ? "start" : (d.along ?? 0.5) > 0.66 ? "end" : "center"
        };
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

    // The studio's edits from the command line (and for testing it):
    //   qs ipc call bar move clock top center ""   (before "" = last)
    IpcHandler {
        target: "bar"

        function move(id: string, edge: string, region: string, before: string): void {
            root.moveWidget(id, edge, region, before);
        }
        function hide(id: string): void {
            root.hideWidget(id);
        }
        // A panel to an edge's region, or a corner (region ""), or back to
        // its default (edge "").
        function place(name: string, edge: string, region: string): void {
            root.placePanel(name, edge === "" ? null : region === "" ? {
                corner: edge
            } : {
                edge: edge,
                region: region
            });
        }
        function edge(edge: string, key: string, value: string): void {
            root.setEdge(edge, key, value);
        }
        function corner(corner: string, value: string): void {
            root.setCorner(corner, value);
        }
        function preset(name: string): void {
            root.usePreset(name);
        }
        function save(): void {
            root.save();
        }
        function revert(): void {
            root.revert();
        }
        // The layout in effect (the draft while editing), as JSON.
        function json(): string {
            return JSON.stringify(root.layout);
        }
    }
}
