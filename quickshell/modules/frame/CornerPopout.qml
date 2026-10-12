pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// A corner's popout: one drawer anchored to a corner of the frame that shows
// whichever of its kinds a bar control opened ("bar:<kind>"), and morphs
// between them with the corner springs. It keeps a generous minimum size,
// so a corner reads as a corner piece even when its content is short.
//
//   components  { kind: Component } this corner hosts
Drawer {
    id: root

    required property var components
    // Plugins' popouts for this corner (Plugins.popoutsFor): { kind: { url, width } }.
    readonly property var pluginPopouts: Plugins.popoutsFor(corner)
    // Kinds that need another width than the default ({ kind: px }).
    property var widths: ({})
    property int minHeight: 420
    readonly property int pad: Tokens.spacing.large
    // On the bar's side the content starts right at the bar's icons (they're
    // the panel's tabs), not a full margin away.
    readonly property int barPad: Tokens.spacing.small

    readonly property string current: ShellState.current(screenName)
    readonly property string kind: current.startsWith("bar:") && (components[current.slice(4)] || pluginPopouts[current.slice(4)]) ? current.slice(4) : ""
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

    name: "corner:" + corner
    key: kind ? `bar:${kind}` : name
    open: enabled && kind !== ""
    edge: "corner"
    hoverZone: false
    panelWidth: widths[shownKind] ?? pluginPopouts[shownKind]?.width ?? 380
    panelHeight: Math.max(minHeight, (loader.item?.implicitHeight ?? 0) + pad * 2)

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

        x: root.cornerRight ? root.pad : root.barPad
        y: root.pad
        width: root.panelWidth - root.pad - root.barPad
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
