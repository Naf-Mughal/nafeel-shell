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

    onKindChanged: {
        if (!kind)
            return;
        // Switching to other content while open: it soaks in again.
        if (shownKind !== "" && shownKind !== kind && open)
            resoak();
        shownKind = kind;
    }

    name: side ? "edge:" + side : "corner:" + corner
    key: kind ? `bar:${kind}` : name
    open: enabled && kind !== ""
    edge: side || "corner"
    // An edge's: centred on the widget, kept on the screen.
    along: {
        if (!side)
            return 0.5;
        const len = vertical ? (shellScreen?.width ?? 1) : (shellScreen?.height ?? 1);
        const at = vertical ? ShellState.anchorX : ShellState.anchor;
        const half = (vertical ? panelWidth : panelHeight) / 2 + Tokens.spacing.large;
        return Math.max(half, Math.min(len - half, at)) / len;
    }
    hoverZone: false
    panelWidth: widths[shownKind] ?? pluginPopouts[shownKind]?.width ?? 380
    panelHeight: Math.max(side ? 0 : minHeight, (loader.item?.implicitHeight ?? 0) + pad * 2)

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

    Loader {
        id: loader

        x: root.side || root.cornerRight ? root.pad : root.barPad
        y: root.pad
        width: root.panelWidth - root.pad - (root.side ? root.pad : root.barPad)
        // Made afresh each time it opens, as the wallpaper picker is.
        active: root.active
        sourceComponent: root.components[root.shownKind] ?? (root.pluginPopouts[root.shownKind] ? Qt.createComponent(root.pluginPopouts[root.shownKind].url) : null)
        // Opened pinned (a keybind): the panel arrives after the frame got
        // the keyboard, so it takes it now.
        onLoaded: if (root.pinnedHere())
            Qt.callLater(() => loader.item?.takeFocus?.())
    }

    function pinnedHere(): bool {
        return kind !== "" && ShellState.pinned === `bar:${kind}`;
    }

    Connections {
        target: ShellState

        function onKeyboardGranted(req: var): void {
            if (root.pinnedHere() && loader.item?.takeFocus?.())
                req.taken = true;
        }
    }
}
