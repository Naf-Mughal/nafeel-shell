pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// A corner's popout: one drawer anchored to a corner of the frame that shows
// whichever kind a bar control opened ("bar:<kind>") when that control sits
// at this corner's end of a bar (BarLayout.cornerFor), and morphs between
// them with the corner springs. It keeps a generous minimum size,
// so a corner reads as a corner piece even when its content is short.
//
//   components  { kind: Component } this corner hosts
//   side        set ("left" | "top" | "right" | "bottom"), it's an edge's
//               popout instead: for the widgets in that edge's centre, a
//               drawer out of the edge at the widget (ShellState.anchor)
Drawer {
    id: root

    required property var components
    property string side: ""
    // An edge popout's icon pill (FrameWindow.pillRect): its length along the
    // edge and its middle (-1 for none). The popout grows out of it, at least
    // as long; a popout whose icon is hidden centres on it.
    property real pillLength: 0
    property real pillAlong: -1
    // Popouts here with their icon hidden: hovering the spot opens the first.
    readonly property var standalone: Object.keys(Object.assign({}, components, pluginPopouts)).filter(k => (BarLayout.catalogue[BarLayout.iconOf(k)] === undefined || !BarLayout.placeOf(BarLayout.iconOf(k))) && BarLayout.cornerFor(k) === place)
    // What BarLayout.cornerFor names this one.
    readonly property string place: side ? "edge:" + side : corner
    // Plugins' popouts (Plugins.popouts): { kind: { url, width } }.
    readonly property var pluginPopouts: Plugins.popouts
    // Kinds that need another width than the default ({ kind: px }).
    property var widths: ({})
    property int minHeight: 420

    readonly property int pad: Tokens.spacing.large
    // On the bar's side the content starts right at the bar's icons (they're
    // the panel's tabs), not a full margin away.
    readonly property int barPad: Tokens.spacing.small

    readonly property string current: ShellState.current(screenName)
    readonly property string kind: {
        if (!current.startsWith("bar:"))
            return "";
        const k = current.slice(4);
        return (components[k] || pluginPopouts[k]) && BarLayout.cornerFor(k) === place ? k : "";
    }
    // What's shown: kept while the drawer closes, so it doesn't empty first.
    property string shownKind: ""

    // A bar popout of this corner's being grabbed: its content shown ahead.
    function grabs(panel: string): bool {
        if (!panel.startsWith("bar:"))
            return false;
        const k = panel.slice(4);
        return !!(components[k] || pluginPopouts[k]) && BarLayout.cornerFor(k) === place;
    }
    onPreparingChanged: {
        if (preparing)
            shownKind = ShellState.grabbing.slice(4);
    }

    onKindChanged: {
        if (!kind)
            return;
        // Switching to other content while open: it soaks in again.
        if (shownKind !== "" && shownKind !== kind && open)
            resoak();
        shownKind = kind;
    }

    name: side ? "edge:" + side : "corner:" + corner
    key: kind ? `bar:${kind}` : standalone.length > 0 ? `bar:${standalone[0]}` : name
    open: enabled && kind !== ""
    edge: side || "corner"
    // An edge's: centred on the widget, kept on the screen.
    along: {
        if (!side)
            return 0.5;
        const len = vertical ? (shellScreen?.width ?? 1) : (shellScreen?.height ?? 1);
        const iconShown = BarLayout.placeOf(BarLayout.iconOf(kind || shownKind)) !== null;
        // At its icon; with the icon hidden, on the pill there, or the
        // edge's middle.
        const at = iconShown ? (vertical ? ShellState.anchorX : ShellState.anchor) : pillAlong >= 0 ? pillAlong : len / 2;
        const half = (vertical ? panelWidth : panelHeight) / 2 + Tokens.spacing.large;
        return Math.max(half, Math.min(len - half, at)) / len;
    }
    hoverZone: standalone.length > 0
    // A panel's own width (where it's going, not the spring on the way).
    function widthOf(k: string): real {
        return Math.max(side && vertical ? pillLength : 0, widths[k] ?? pluginPopouts[k]?.width ?? 380);
    }
    panelWidth: widthOf(shownKind)
    panelHeight: Math.max(side ? (vertical ? 0 : pillLength) : minHeight, (loader?.item?.implicitHeight ?? 0) + pad * 2)

    Behavior on panelWidth {
        enabled: root.active
        SpringAnimation {
            spring: Tokens.spring.spatial.spring
            damping: Tokens.spring.spatial.damping
            epsilon: 0.25
        }
    }

    Behavior on panelHeight {
        enabled: root.active
        SpringAnimation {
            spring: Tokens.spring.spatial.spring
            damping: Tokens.spring.spatial.damping
            epsilon: 0.25
        }
    }

    // The panels that open here (BarLayout.cornerFor), each its own warm
    // content: built ahead (Prewarm) and kept, the current one shown, so
    // switching between them never rebuilds one (ROADMAP O4).
    readonly property var hosted: Object.keys(Object.assign({}, components, pluginPopouts)).filter(k => BarLayout.cornerFor(k) === place)
    property var loaders: []
    // The shown panel's loader.
    readonly property Loader loader: loaders.find(l => l.kind === shownKind) ?? null

    Repeater {
        model: root.hosted
        onItemAdded: (i, item) => root.loaders = root.loaders.concat([item])
        onItemRemoved: (i, item) => root.loaders = root.loaders.filter(l => l !== item)

        Loader {
            id: panelLoader

            required property string modelData
            readonly property string kind: modelData
            readonly property bool shown: root.shownKind === kind
            property int turn: -1

            x: root.side || root.cornerRight ? root.pad : root.barPad
            y: root.pad
            // At its own width, not the animated one: on the springing width
            // every warm panel here (shown or not) laid itself out again on
            // every frame of a switch between two widths (cards, lists,
            // pictures asked for at each size): seconds of stutter and a
            // decode per frame.
            width: root.widthOf(kind) - root.pad - (root.side ? root.pad : root.barPad)
            visible: shown
            // Its place in the warm-up queue, taken once.
            Component.onCompleted: turn = Prewarm.enlist(`popout ${kind} (${root.place})`)
            active: (shown && root.active) || Prewarm.due(turn)
            asynchronous: !(shown && root.active)
            sourceComponent: root.components[kind] ?? (root.pluginPopouts[kind] ? Qt.createComponent(root.pluginPopouts[kind].url) : null)
            // Opened pinned (a keybind): the panel arrives after the frame
            // got the keyboard, so it takes it now.
            onLoaded: if (shown && root.pinnedHere())
                Qt.callLater(() => panelLoader.item?.takeFocus?.())
        }
    }

    function pinnedHere(): bool {
        return kind !== "" && ShellState.current(ShellState.screen) === `bar:${kind}`;
    }

    Connections {
        target: ShellState

        function onKeyboardGranted(req: var): void {
            if (root.pinnedHere() && loader?.item?.takeFocus?.())
                req.taken = true;
        }
    }
}
