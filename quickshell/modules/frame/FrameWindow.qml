pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Nafeel
import qs.config
import qs.services
import qs.components
import qs.modules.bar
import qs.modules.bar.popouts
import qs.modules.commandcenter
import qs.modules.settings

// A full-screen layer surface that draws the frame, the bar and the drawers
// as one shape (SDF blobs: BlobGroup, below). The frame's edges are reserved in umbriel
// (layout.struts, set by the plugin service). Only the frame and open drawers
// take input; the desktop hole passes through, except while a drawer is
// pinned, when a click anywhere outside it closes it.
PanelWindow {
    id: win

    readonly property bool fullscreen: Umbriel.fullscreenOn(screen?.name ?? "", screen?.width ?? 0, screen?.height ?? 0)
    property real fsProg: fullscreen ? 1 : 0
    readonly property real border: Tokens.border * (1 - fsProg)
    readonly property real barWidth: Tokens.barWidth * (1 - fsProg)
    readonly property bool pinnedHere: ShellState.isPinned(screen?.name ?? "")
    // A modal plugin drawer (one that opens by itself, e.g. an
    // authentication prompt) is up here: it takes the keyboard, and the dock
    // makes way.
    readonly property bool modalHere: pluginDrawers.some(d => d.modal && d.open)
    readonly property bool focusedHere: Umbriel.focusedOutput === "" || Umbriel.focusedOutput === (screen?.name ?? "")

    // Every drawer on this screen (the blob engine takes up to sixteen shapes
    // near any one).
    readonly property var drawers: [commandCenter, topLeft, bottomLeft, settings].concat(pluginDrawers)
    // The drawers plugins add (their manifests: Plugins.drawers).
    property var pluginDrawers: []

    // Whether the drawer called `name` (a plugin's or the kernel's) is open
    // here.
    function drawerOpen(name: string): bool {
        return drawers.some(d => d.name === name && d.open);
    }

    function drawerRegion(i: int): rect {
        return i < drawers.length && drawers[i].active ? drawers[i].region : Qt.rect(0, 0, 0, 0);
    }

    onFullscreenChanged: {
        if (fullscreen)
            ShellState.close();
    }

    Behavior on fsProg {
        Anim {}
    }

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "nafeel-shell-frame"
    WlrLayershell.layer: WlrLayer.Top
    // A pinned drawer (opened by a keybind or a click) takes the keyboard, so
    // Esc closes it and its fields can be typed in straight away; a hover
    // preview never does, so typing in apps isn't interrupted.
    WlrLayershell.keyboardFocus: modalHere || pinnedHere ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None


    mask: fullscreen ? noInput : pinnedHere ? everywhere : frameInput

    // Caffeine: keeps the session from going idle (dim, lock, sleep) while on.
    IdleInhibitor {
        window: win
        enabled: Display.caffeine
    }

    Region {
        id: noInput
    }

    Region {
        id: everywhere

        width: win.width
        height: win.height
    }

    // The whole window XOR the desktop hole = the frame; open drawers are
    // then cut back out of the hole.
    Region {
        id: frameInput

        x: win.barWidth
        y: win.border
        width: win.width - win.barWidth - win.border
        height: win.height - win.border * 2
        intersection: Intersection.Xor

        DrawerRegion {
            index: 0
        }
        DrawerRegion {
            index: 1
        }
        DrawerRegion {
            index: 2
        }
        DrawerRegion {
            index: 3
        }
        DrawerRegion {
            index: 4
        }
        DrawerRegion {
            index: 5
        }
        DrawerRegion {
            index: 6
        }
        DrawerRegion {
            index: 7
        }
        DrawerRegion {
            index: 8
        }
        DrawerRegion {
            index: 9
        }
        DrawerRegion {
            index: 10
        }
        DrawerRegion {
            index: 11
        }
        DrawerRegion {
            index: 12
        }
        DrawerRegion {
            index: 13
        }
        DrawerRegion {
            index: 14
        }
        DrawerRegion {
            index: 15
        }
    }

    // Outside click / Esc closes a pinned drawer.
    // (Not on the bar, whose icons toggle and switch panels themselves, and
    // not inside an open drawer.)
    MouseArea {
        anchors.fill: parent
        enabled: win.pinnedHere
        onPressed: mouse => {
            // Presses inside an open drawer belong to it: handlers in there
            // don't stop a press reaching this catcher below.
            const inside = win.drawers.some(d => {
                if (!d.active)
                    return false;
                const r = d.region;
                return mouse.x >= r.x && mouse.x < r.x + r.width && mouse.y >= r.y && mouse.y < r.y + r.height;
            });
            if (inside || mouse.x < win.barWidth) {
                mouse.accepted = false;
                return;
            }
            ShellState.close();
        }
    }

    Item {
        id: escCatcher

        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: ShellState.close()

        // When a drawer gets pinned, its search field (if it has one) takes
        // the keyboard; otherwise this does, so Esc closes it. (A window here
        // has no activeFocusItem to ask, so the drawer says so itself.)
        function claim(): void {
            if (!win.pinnedHere)
                return;
            const req = {
                taken: false
            };
            ShellState.keyboardGranted(req);
            if (!req.taken)
                escCatcher.forceActiveFocus();
        }

        Connections {
            target: win

            function onPinnedHereChanged(): void {
                Qt.callLater(escCatcher.claim);
            }
        }
    }

    // Plugins' overlays: in every frame window, open drawer or not (the
    // switcher's keys work before its carousel shows).
    Instantiator {
        model: Plugins.overlays

        delegate: Loader {
            required property var modelData

            parent: win.contentItem
            anchors.fill: parent
            active: Plugins.isEnabled(modelData.plugin)
            source: modelData.url
            onLoaded: {
                if ("shellScreen" in item)
                    item.shellScreen = Qt.binding(() => win.screen);
            }
        }
    }

    // The frame and every open drawer as SDF blobs (Ryoku's engine, in the
    // Nafeel module): the frame a BlobInvertedRect, each drawer a BlobRect,
    // merged with circular fillets where they meet; each squashes and
    // stretches with its own velocity. Drawn opaque inside one layer and faded
    // as a whole (the frosted paper), so where shapes overlap there are no
    // seams.
    Item {
        id: paper

        anchors.fill: parent
        layer.enabled: true
        opacity: Tokens.transparency.enabled ? Tokens.transparency.base : 1

        BlobGroup {
            id: blobs

            color: Colours.palette.m3surface
            smoothing: Tokens.frameSmoothing
            // Xianxia ornament: ink wash and grain, paper fibre (its setting),
            // and a gilded edge (stronger when fully immersive).
            ink: Tokens.immersive ? 1 : 0.55
            fibre: Tokens.paperTexture
            gild: (Tokens.immersive ? 0.4 : 0.25) * (1 - win.fsProg)
            accent: Colours.palette.m3primary
        }

        BlobInvertedRect {
            group: blobs
            anchors.fill: parent
            borderLeft: win.barWidth
            borderTop: win.border
            borderRight: win.border
            borderBottom: win.border
            radius: Tokens.frameRounding * (1 - win.fsProg)
        }

        Repeater {
            model: win.drawers

            BlobRect {
                id: blob

                required property Drawer modelData
                readonly property rect r: modelData.active ? modelData.region : Qt.rect(0, 0, 0, 0)

                group: blobs
                x: r.x
                y: r.y
                width: r.width
                height: r.height
                visible: modelData.active
                // Flush with the frame where it grows out of it (no pocket).
                sinks: false
                radius: Tokens.rounding.large
                topLeftRadius: modelData.radii.x
                topRightRadius: modelData.radii.y
                bottomRightRadius: modelData.radii.z
                bottomLeftRadius: modelData.radii.w
                // The goo, pinned at the side it grows out of, so only the
                // free edge springs and it stays part of the bar (a corner
                // bounces outward rather than tilting).
                anchor: modelData.goo
                axisAligned: modelData.isCorner
                stiffness: Tokens.goo.stiffness
                damping: Tokens.goo.damping
                deformScale: Tokens.goo.enabled ? Tokens.goo.scale : 0
                maxStretch: Tokens.goo.maxStretch

                Component.onCompleted: modelData.blob = blob
            }
        }
    }


    // Above every drawer: the corners and popouts that merge into the bar
    // cover its strip, and its icons must still get the pointer (hovering
    // from one icon to the next switches the panel).
    Bar {
        z: 2
        x: 0
        width: Tokens.barWidth
        height: parent.height
        opacity: 1 - win.fsProg
        visible: opacity > 0
        shellScreen: win.screen
    }

    // The dock and the command center, one drawer at the bottom centre:
    // hidden while the workspace has windows (hovering the bottom edge shows
    // it), the dock while it's empty, and resting on the dock grows it into
    // the command center.
    Drawer {
        id: commandCenter

        readonly property string current: ShellState.current(screenName)
        readonly property bool expanded: current === "command"
        readonly property bool workspaceEmpty: {
            const ws = Umbriel.activeWorkspace(screenName);
            return !ws || Umbriel.windowsOn(ws.id).length === 0;
        }

        name: "command"
        key: expanded ? "command" : "dock"
        open: enabled && !win.modalHere && (expanded || current === "dock" || workspaceEmpty)
        pinOnPress: expanded
        wantsKeyboard: expanded
        edge: "bottom"
        thickness: win.border
        shellScreen: win.screen
        enabled: !win.fullscreen
        // Grown by the window previews while one app's show above the dock.
        panelWidth: expanded ? 920 : Math.max(160, Math.max(content.dockWidth, content.previewWidth) + Tokens.spacing.large * 2)
        panelHeight: expanded ? 640 : content.dockHeight + content.previewHeight

        Behavior on panelWidth {
            enabled: commandCenter.active
            SpringAnimation {
                spring: Tokens.springK(3.2)
                damping: Tokens.dampK(0.32)
                epsilon: 0.25
            }
        }
        Behavior on panelHeight {
            enabled: commandCenter.active
            SpringAnimation {
                spring: Tokens.springK(3.2)
                damping: Tokens.dampK(0.32)
                epsilon: 0.25
            }
        }

        CommandCenter {
            id: content

            anchors.fill: parent
            expanded: commandCenter.expanded
            shellScreen: win.screen
            // (The dock's middle icon opens the command center on hover; the
            // rest of the dock doesn't.)
        }
    }

    // ── Corners ───────────────────────────────────────────────────────────
    // Each grows out of its corner point, merged into both bars it touches.

    // The bar's corners, merged into the bar so they read as part of it: the
    // top-left holds what the bar's top icons open, the bottom-left what its
    // bottom icons open.
    CornerPopout {
        id: topLeft

        corner: "topLeft"
        thickness: win.barWidth
        thicknessY: win.border
        shellScreen: win.screen
        enabled: !win.fullscreen
        minHeight: 460
        // All of it from plugins (workspaces, notifications, clipboard,
        // capture: their manifests' "popouts").
        components: ({})
    }

    CornerPopout {
        id: bottomLeft

        corner: "bottomLeft"
        thickness: win.barWidth
        thicknessY: win.border
        shellScreen: win.screen
        enabled: !win.fullscreen
        minHeight: 420
        components: ({
                session: sessionPopout,
                sound: soundPopout,
                connect: connectPopout,
                battery: batteryPopout
            })
    }

    Component {
        id: sessionPopout

        SessionPopout {}
    }
    Component {
        id: soundPopout

        SoundPopout {}
    }
    Component {
        id: connectPopout

        ConnectPopout {}
    }
    Component {
        id: batteryPopout

        BatteryPopout {}
    }

    // Settings, out of the top bar's centre (Mod+S): keyboard while open.
    Drawer {
        id: settings

        name: "settings"
        edge: "top"
        thickness: win.border
        shellScreen: win.screen
        enabled: !win.fullscreen
        hoverZone: false
        wantsKeyboard: true
        panelWidth: Math.min(900, win.width - 2 * win.barWidth - 160)
        panelHeight: (settingsLoader.item?.implicitHeight ?? 540) + Tokens.spacing.large * 2

        Loader {
            id: settingsLoader

            anchors.fill: parent
            anchors.margins: Tokens.spacing.large
            active: settings.active
            sourceComponent: SettingsPanel {}
        }
    }


    // ── Plugins' drawers ──
    // One per drawer a plugin's manifest declares, enabled while the plugin
    // is on: its entry inside, the size and place from the manifest. They join the
    // frame's shape like the kernel's own.
    Instantiator {
        model: Plugins.drawers

        delegate: Drawer {
            id: pd

            required property var modelData
            // "openWhen": the drawer opens by itself while the plugin's root
            // has that property true (on the focused screen), not through the
            // usual hover / pin. "modal": it then takes the keyboard and the
            // dock makes way.
            readonly property var instance: Plugins.instance(modelData.plugin)
            readonly property bool modal: modelData.modal === true
            // "yieldTo": stays shut while these drawers are open (they show
            // the same thing their own way). "padding": round the entry
            // (default the panel rhythm; 0 for edge-to-edge content).
            readonly property var yieldTo: modelData.yieldTo ?? []
            readonly property real pad: modelData.padding ?? Tokens.spacing.large

            parent: win.contentItem
            name: modelData.name
            managed: !modelData.openWhen
            // "openIf": the usual open, and the root's property too (the
            // switcher waits a beat). "overFullscreen": usable over a
            // fullscreen window.
            open: (!modelData.openIf || (instance?.[modelData.openIf] ?? false)) && (modelData.openWhen ? enabled && win.focusedHere && (instance?.[modelData.openWhen] ?? false) : enabled && ShellState.isOpen(name, screenName)) && !yieldTo.some(n => win.drawerOpen(n))
            edge: modelData.edge ?? "top"
            corner: modelData.corner ?? "bottomRight"
            along: modelData.along ?? 0.5
            thickness: win.border
            thicknessY: win.border
            shellScreen: win.screen
            enabled: Plugins.isEnabled(modelData.plugin) && (modelData.overFullscreen === true || !win.fullscreen)
            hoverZone: modelData.hoverZone ?? false
            zoneLength: modelData.zoneLength ?? 0
            wantsKeyboard: modelData.keyboard ?? false
            // The manifest's width, never wider than the screen leaves room
            // for; "content" height follows the entry, springing as it
            // changes (a dashboard tab, say).
            panelWidth: modelData.width === "content" ? (pdLoader.item?.implicitWidth ?? 200) + pad * 2 : Math.min(modelData.width ?? 400, win.width - 2 * win.barWidth - 160)
            panelHeight: modelData.height === "content" ? (pdLoader.item?.implicitHeight ?? 300) + pad * 2 : Math.min(modelData.height ?? 300, win.height - 120)

            Behavior on panelHeight {
                enabled: pd.active && pd.modelData.height === "content"
                SpringAnimation {
                    spring: Tokens.spring.spatial.spring
                    damping: Tokens.spring.spatial.damping
                    epsilon: 0.25
                }
            }
            Behavior on panelWidth {
                enabled: pd.active && pd.modelData.width === "content"
                SpringAnimation {
                    spring: Tokens.spring.spatial.spring
                    damping: Tokens.spring.spatial.damping
                    epsilon: 0.25
                }
            }

            Loader {
                id: pdLoader

                anchors.fill: parent
                anchors.margins: pd.pad
                active: pd.active
                source: pd.modelData.url
                // Content that sizes itself can know the room it has.
                onLoaded: {
                    if (item && "availableWidth" in item)
                        item.availableWidth = Qt.binding(() => win.width - 2 * win.barWidth);
                }
            }
        }

        onObjectAdded: (i, o) => win.pluginDrawers = win.pluginDrawers.concat([o])
        onObjectRemoved: (i, o) => win.pluginDrawers = win.pluginDrawers.filter(d => d !== o)
    }

    component DrawerRegion: Region {
        required property int index
        readonly property rect r: win.drawerRegion(index)

        x: r.x
        y: r.y
        width: r.width
        height: r.height
        intersection: Intersection.Subtract
    }

    // The shell's ink transition: this window's still (the frame, the bars,
    // every open panel) soaks away over the new look.
    InkStill {}
}
