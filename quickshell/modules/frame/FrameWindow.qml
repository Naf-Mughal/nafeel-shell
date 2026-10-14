pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Nafeel
import qs.config
import qs.services
import qs.components
import "../../components/keynav.js" as KeyNav
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
    // Each edge's thickness: a bar's where the layout puts widgets, the thin
    // border elsewhere (BarLayout).
    // An autohidden full bar shrinks to the strip as it hides.
    readonly property real tLeft: revealed("left") * (1 - fsProg)
    readonly property real tTop: revealed("top") * (1 - fsProg)
    readonly property real tRight: revealed("right") * (1 - fsProg)
    readonly property real tBottom: revealed("bottom") * (1 - fsProg)

    function revealed(edge: string): real {
        const full = BarLayout.thickness(edge);
        const bar = barItems.find(b => b.edge === edge);
        return Tokens.border + (full - Tokens.border) * (bar ? bar.reveal : 1);
    }
    // The desktop's width between the side bars.
    readonly property real innerWidth: width - tLeft - tRight

    // The bars (one per edge), and their bulges in window coordinates
    // ({ r: rect, edge }: regions-mode regions with icon widgets).
    property var barItems: []
    readonly property var bulges: fsProg > 0.99 ? [] : barItems.reduce((out, b) => out.concat(b.visible ? b.bulges.map(r => ({
                        r: Qt.rect(b.x + r.x, b.y + r.y, r.width, r.height),
                        edge: b.edge
                    })) : []), [])

    function bulgeRegion(i: int): rect {
        return i < bulges.length ? bulges[i].r : Qt.rect(0, 0, 0, 0);
    }

    function onBulge(x: real, y: real): bool {
        return bulges.some(b => x >= b.r.x && x < b.r.x + b.r.width && y >= b.r.y && y < b.r.y + b.r.height);
    }

    // A region's icon pill in window coordinates (Bar.pill), or null.
    function pillRect(edge: string, region: string): var {
        const bar = barItems.find(b => b.edge === edge);
        const r = bar && bar.visible ? bar.pill(region) : null;
        return r ? Qt.rect(bar.x + r.x, bar.y + r.y, r.width, r.height) : null;
    }

    // Where a panel opens (ROADMAP B5), as a drawer's geometry:
    //   { edge, corner, along, thickness, thicknessY, length, hoverZone }
    // From the layout's place for it (`panels.<name>`), else from its
    // manifest (`def`: edge, corner, along, hoverZone). A place in a
    // region with an icon pill grows out of the pill: along its middle, at
    // least its `length`, from its thickness. One placed in a start or end
    // region by the layout opens at that corner.
    function placeOf(name: string, def: var): var {
        const set = BarLayout.panelPlace(name);
        let at = set;
        if (!at)
            at = def.edge === "corner" ? {
                corner: def.corner
            } : {
                edge: def.edge ?? "top",
                region: (def.along ?? 0.5) < 0.34 ? "start" : (def.along ?? 0.5) > 0.66 ? "end" : "center"
            };
        const corner = at.corner ?? (set && at.region !== "center" ? BarLayout.target(at) : "");
        if (corner)
            return {
                edge: "corner",
                corner: corner,
                along: 0.5,
                thickness: corner.endsWith("Right") ? tRight : tLeft,
                thicknessY: corner.startsWith("bottom") ? tBottom : tTop,
                length: 0,
                hoverZone: set ? true : (def.hoverZone ?? false)
            };
        const pill = pillRect(at.edge, at.region);
        const horizontal = at.edge === "top" || at.edge === "bottom";
        const len = horizontal ? width : height;
        const t = edgeThickness(at.edge);
        return {
            edge: at.edge,
            corner: "",
            along: pill ? (horizontal ? pill.x + pill.width / 2 : pill.y + pill.height / 2) / len : set ? ({
                    start: 0.2,
                    center: 0.5,
                    end: 0.8
                })[at.region] : (def.along ?? 0.5),
            thickness: pill ? Math.max(t, horizontal ? pill.height : pill.width) : t,
            thicknessY: pill ? Math.max(t, horizontal ? pill.height : pill.width) : t,
            length: pill ? (horizontal ? pill.width : pill.height) : 0,
            hoverZone: set ? true : (def.hoverZone ?? false)
        };
    }

    function edgeThickness(edge: string): real {
        return edge === "left" ? tLeft : edge === "right" ? tRight : edge === "top" ? tTop : tBottom;
    }
    readonly property bool pinnedHere: ShellState.isPinned(screen?.name ?? "")
    // The panel open here, however it opened (a hover, a click, a keybind):
    // it has the keyboard, its own keys (a search field, arrows) at once.
    readonly property string openHere: ShellState.current(screen?.name ?? "")
    // A modal plugin drawer (one that opens by itself, e.g. an
    // authentication prompt) is up here: it takes the keyboard, and the dock
    // makes way.
    readonly property bool modalHere: pluginDrawers.some(d => d.modal && d.open)
    readonly property bool focusedHere: Umbriel.focusedOutput === "" || Umbriel.focusedOutput === (screen?.name ?? "")
    // The edit mode on the bar is up here (on the focused screen).
    readonly property bool editingHere: BarLayout.editing && focusedHere && !fullscreen

    // Every drawer on this screen (the blob engine takes up to sixteen shapes
    // near any one).
    readonly property var drawers: [commandCenter, topLeft, bottomLeft, topRight, bottomRight, settings].concat(edgePopouts, pluginDrawers)
    // The edges' popouts (made by a Repeater).
    property var edgePopouts: []
    // The drawers plugins add (their manifests: Plugins.drawers).
    property var pluginDrawers: []

    // Whether the drawer called `name` (a plugin's or the kernel's) is open
    // here.
    function drawerOpen(name: string): bool {
        return drawers.some(d => d.name === name && d.open);
    }

    function drawerRegion(i: int): rect {
        // Kept while it leaves: a mask change is a surface commit from the
        // GUI thread, an extra frame if it lands on the close's first one.
        return i < drawers.length && (drawers[i].open || drawers[i].active) ? drawers[i].restRegion : Qt.rect(0, 0, 0, 0);
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
    // A hover preview has the keyboard too (not the pointer outside it: the
    // input mask stays the frame's, so clicks still reach the windows).
    WlrLayershell.keyboardFocus: kbWanted || kbHeld || focusHeld ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    readonly property bool kbWanted: wantsFocus || openHere !== "" || grabbingHere
    // The keyboard (alone: not the input mask) held through a hover
    // preview's close, as focusHeld does for a pinned panel's.
    property bool kbHeld: false
    onKbWantedChanged: {
        if (kbWanted) {
            kbHeld = false;
            kbRelease.stop();
        } else {
            kbHeld = true;
            kbRelease.restart();
        }
    }
    readonly property bool wantsFocus: modalHere || pinnedHere || editingHere || (grabbingHere && !ShellState.grabPreview)
    readonly property bool grabbingHere: ShellState.grabbing !== "" && ShellState.screen === (screen?.name ?? "")
    // Let go of the keyboard once a closing panel has settled, not as it
    // starts: handing focus back makes the compositor re-arrange its layers
    // (the wallpaper redraws), and on the close's first frames that cost one.
    property bool focusHeld: false

    // Held as a close begins (ShellState.closing), before the panel's state
    // changes: set only when wantsFocus fell, the focus and the input mask
    // flipped to released and straight back in between, two surface commits
    // from the GUI thread and an extra frame on the close's first refresh.
    Connections {
        target: ShellState

        function onClosingChanged(): void {
            if (ShellState.closing && win.wantsFocus) {
                win.focusHeld = true;
                focusRelease.stop();
            }
            if (ShellState.closing && win.kbWanted) {
                win.kbHeld = true;
                kbRelease.stop();
            }
        }
    }

    onWantsFocusChanged: {
        if (wantsFocus) {
            focusHeld = false;
            focusRelease.stop();
        } else {
            focusHeld = true;
            focusRelease.restart();
        }
    }

    // Qt's render loop, when animations start from rest, redraws every window
    // the shell has: the wallpaper too, a full-screen frame whose second sync
    // blocks the GUI thread for up to a vsync, and a panel's close (or
    // anything starting then) loses a frame. So from the moment a panel opens
    // until its close has settled the animations never come to rest: this
    // ticks a value nothing draws (no frame is rendered for it). At rest, with
    // no panel, it's stopped and the shell sleeps.
    property real keepAwake: 0
    NumberAnimation on keepAwake {
        running: ShellState.pinned !== "" || ShellState.previewed !== "" || ShellState.grabbing !== "" || ShellState.moving > 0 || win.focusHeld || win.kbHeld
        from: 0
        to: 1
        duration: 1000
        loops: Animation.Infinite
    }

    // A pixel nobody sees, changed at every vblank-paced step, keeps the
    // window drawing in step with the display: left idle, umbriel shows the
    // first frame after a rest at once and settles onto its vblank schedule
    // only a few frames later, a skipped refresh early in a close.
    // While a panel is open, so a close starts in step: no skipped refresh.
    // It costs GPU for as long as a panel stays open (~24% here: each frame
    // redraws and recomposites the surface); smooth panels come first, the
    // power pass revisits it. At rest (no panel) it's stopped.
    property real pumpPhase: 0
    NumberAnimation on pumpPhase {
        // From the grab before an open too: the window drawing in step at
        // every vblank before the motion's first frame (started with it,
        // the open's second or third refresh was skipped).
        running: ShellState.closePending || ShellState.pinned !== "" || ShellState.previewed !== "" || ShellState.grabbing !== ""
        from: 0
        to: 1
        duration: 100
        loops: Animation.Infinite
    }
    Rectangle {
        width: 1
        height: 1
        color: Qt.rgba(0, 0, 0, 0.002 + 0.002 * win.pumpPhase)
    }

    // Animations advanced at the display's vblanks (Nafeel's FramePacer:
    // vsync-locked though the wallpaper is a second window).
    readonly property var quickWindow: escCatcher.Window.window
    onQuickWindowChanged: {
        if (quickWindow)
            FramePacer.attach(quickWindow);
    }

    Timer {
        id: focusRelease

        // Once the close's springs have been still for 250 ms (its fades and
        // soak are over by then too); at most 1.2 s.
        interval: 50
        repeat: true
        property int ticks: 0
        property int still: 0
        onRunningChanged: ticks = still = 0
        onTriggered: {
            still = ShellState.moving === 0 ? still + 1 : 0;
            if (still >= 5 || ++ticks > 24) {
                stop();
                win.focusHeld = false;
            }
        }
    }


    Timer {
        id: kbRelease

        interval: 50
        repeat: true
        property int ticks: 0
        property int still: 0
        onRunningChanged: ticks = still = 0
        onTriggered: {
            still = ShellState.moving === 0 ? still + 1 : 0;
            if (still >= 5 || ++ticks > 24) {
                stop();
                win.kbHeld = false;
            }
        }
    }

    mask: fullscreen ? noInput : wantsFocus || focusHeld ? everywhere : frameInput

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

        x: win.tLeft
        y: win.tTop
        width: win.innerWidth
        height: win.height - win.tTop - win.tBottom
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
        DrawerRegion {
            index: 16
        }
        DrawerRegion {
            index: 17
        }
        DrawerRegion {
            index: 18
        }
        DrawerRegion {
            index: 19
        }

        // The bars' bulges (at most three per edge).
        DrawerRegion {
            index: 0
            bulge: true
        }
        DrawerRegion {
            index: 1
            bulge: true
        }
        DrawerRegion {
            index: 2
            bulge: true
        }
        DrawerRegion {
            index: 3
            bulge: true
        }
        DrawerRegion {
            index: 4
            bulge: true
        }
        DrawerRegion {
            index: 5
            bulge: true
        }
        DrawerRegion {
            index: 6
            bulge: true
        }
        DrawerRegion {
            index: 7
            bulge: true
        }
        DrawerRegion {
            index: 8
            bulge: true
        }
        DrawerRegion {
            index: 9
            bulge: true
        }
        DrawerRegion {
            index: 10
            bulge: true
        }
        DrawerRegion {
            index: 11
            bulge: true
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
            const onBar = mouse.x < win.tLeft || mouse.x >= win.width - win.tRight || mouse.y < win.tTop || mouse.y >= win.height - win.tBottom;
            if (inside || onBar || win.onBulge(mouse.x, mouse.y)) {
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
        // A panel without a field of its own: Tab or an arrow walks into it
        // (its first control), then on through it (Surface, keynav.js).
        Keys.onPressed: event => {
            const fwd = event.key === Qt.Key_Tab || event.key === Qt.Key_Down || event.key === Qt.Key_Right;
            const back = event.key === Qt.Key_Backtab || event.key === Qt.Key_Up || event.key === Qt.Key_Left;
            if (!fwd && !back)
                return;
            const d = win.drawers.find(d => d.open && d.key === ShellState.pinned);
            if (d && KeyNav.enter(d.navBody, escCatcher, fwd))
                event.accepted = true;
        }

        // When a drawer opens, its own keys take the keyboard (a search
        // field, a list's arrows); otherwise this does, so Esc closes it and
        // Tab walks its controls. (A window here has no activeFocusItem to
        // ask, so the drawer says so itself.)
        function claim(): void {
            if (win.openHere === "")
                return;
            // A QtObject, not a JS object: a signal's `var` hands each
            // handler a copy of a JS object, so `taken` never came back and
            // this took the keyboard from every panel that had claimed it.
            grant.taken = false;
            ShellState.keyboardGranted(grant);
            if (!grant.taken)
                escCatcher.forceActiveFocus();
            if (Quickshell.env("NAFEEL_FOCUS_LOG") === "1")
                focusLog.restart();
        }

        Timer {
            id: focusLog

            interval: 400
            onTriggered: console.info(`focus: ${win.openHere} -> ${escCatcher.Window.activeFocusItem} (window active ${escCatcher.Window.active})`)
        }

        QtObject {
            id: grant

            property bool taken: false
        }

        Connections {
            target: win

            function onOpenHereChanged(): void {
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
            borderLeft: win.tLeft
            borderTop: win.tTop
            borderRight: win.tRight
            borderBottom: win.tBottom
            radius: Tokens.frameRounding * (1 - win.fsProg)
        }

        // The bars' bulges (regions mode): grown out of the strip like the
        // dock, square where they meet the screen's edges.
        Repeater {
            model: win.bulges

            BlobRect {
                required property var modelData
                readonly property rect r: modelData.r
                readonly property real round: Tokens.rounding.large
                readonly property bool atTop: r.y <= 0
                readonly property bool atLeft: r.x <= 0
                readonly property bool atRight: r.x + r.width >= win.width
                readonly property bool atBottom: r.y + r.height >= win.height

                group: blobs
                x: r.x
                y: r.y
                width: r.width
                height: r.height
                sinks: false
                radius: round
                topLeftRadius: atTop || atLeft ? 0 : round
                topRightRadius: atTop || atRight ? 0 : round
                bottomRightRadius: atBottom || atRight ? 0 : round
                bottomLeftRadius: atBottom || atLeft ? 0 : round
                deformScale: 0
            }
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
                // Not while it leaves: kicked from rest by the exit, the
                // underdamped spring briefly cancelled the motion, a frame that
                // looked frozen at the start of every close.
                deformScale: Tokens.goo.enabled && (modelData.open || !modelData.active) ? Tokens.goo.scale : 0
                maxStretch: Tokens.goo.maxStretch

                Component.onCompleted: modelData.blob = blob
            }
        }
    }


    // Above every drawer: the corners and popouts that merge into the bar
    // cover its strip, and its icons must still get the pointer (hovering
    // from one icon to the next switches the panel).
    // A bar on every edge the layout puts widgets on; the side bars run
    // the full height, the top and bottom ones between them.
    Repeater {
        model: BarLayout.edgeNames
        onItemAdded: (i, item) => win.barItems = win.barItems.concat([item])
        onItemRemoved: (i, item) => win.barItems = win.barItems.filter(b => b !== item)

        Bar {
            required property string modelData
            readonly property real t: BarLayout.barThickness(modelData)
            // Along its edge, through the corners it owns (BarLayout.span).
            readonly property var along: BarLayout.span(modelData, win.width, win.height, {
                left: win.tLeft,
                top: win.tTop,
                right: win.tRight,
                bottom: win.tBottom
            })

            z: 2
            edge: modelData
            x: modelData === "right" ? win.width - t : modelData === "left" ? 0 : along[0]
            y: modelData === "bottom" ? win.height - t : modelData === "top" ? 0 : along[0]
            width: horizontal ? along[1] - along[0] : t
            height: horizontal ? t : along[1] - along[0]
            opacity: 1 - win.fsProg
            visible: opacity > 0 && BarLayout.used(modelData)
            shellScreen: win.screen
        }
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
        // Its own region (BarLayout.dockPlace): the bottom's centre unless
        // something else is there.
        readonly property var at: BarLayout.dockPlace
        readonly property bool side: at.edge === "left" || at.edge === "right"
        // Its length along the edge and depth out of it.
        readonly property real dockLength: Math.max(160, Math.max(content.dockWidth, content.previewWidth) + Tokens.spacing.large * 2)
        readonly property real dockDepth: content.dockHeight + content.previewHeight

        edge: at.edge
        // In a centre region, the edge's middle; at a start or end, that end
        // of the bar (past the corner).
        along: {
            const len = side ? win.height : win.width;
            const span = big ? (side ? 640 : 920) : dockLength;
            const lo = side ? win.tTop : win.tLeft, hi = side ? win.tBottom : win.tRight;
            const m = Tokens.spacing.large;
            return (at.region === "start" ? lo + m + span / 2 : at.region === "end" ? len - hi - m - span / 2 : len / 2) / len;
        }
        thickness: win.edgeThickness(at.edge)
        shellScreen: win.screen
        enabled: !win.fullscreen
        // Grown by the window previews while one app's show beside the dock.
        // The command center leaving altogether (no dock to become: a window
        // on the workspace) leaves at its size: switched to the dock's as it
        // closed, it shrank a quarter in one frame before it went. Only it:
        // the dock closing stays the dock's size (grown toward the command
        // center's as it left, it reached back under the pointer and hover
        // opened it again, over and over).
        property bool keepBig: false
        readonly property bool big: expanded || keepBig
        onExpandedChanged: keepBig = !expanded && !(current === "dock" || workspaceEmpty)
        onActiveChanged: {
            if (!active)
                keepBig = false;
        }
        panelWidth: big ? 920 : side ? dockDepth : dockLength
        panelHeight: big ? 640 : side ? dockLength : dockDepth

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
            edge: commandCenter.at.edge
            expanded: commandCenter.expanded
            shellScreen: win.screen
            // (The dock's middle icon opens the command center on hover; the
            // rest of the dock doesn't.)
        }
    }

    // ── Corners ───────────────────────────────────────────────────────────
    // Each grows out of its corner point, merged into both bars it touches.

    // The bar's corners, merged into the bars they touch so they read as
    // part of them: each holds the popouts of the bar widgets at its end of
    // either bar (BarLayout.cornerFor), the kernel's and the plugins'.
    readonly property var cornerPopouts: ({
            session: sessionPopout,
            sound: soundPopout,
            connect: connectPopout,
            battery: batteryPopout
        })

    CornerPopout {
        id: topLeft

        corner: "topLeft"
        thickness: win.tLeft
        thicknessY: win.tTop
        shellScreen: win.screen
        enabled: !win.fullscreen
        minHeight: 460
        components: win.cornerPopouts
    }

    CornerPopout {
        id: bottomLeft

        corner: "bottomLeft"
        thickness: win.tLeft
        thicknessY: win.tBottom
        shellScreen: win.screen
        enabled: !win.fullscreen
        minHeight: 420
        components: win.cornerPopouts
    }

    CornerPopout {
        id: topRight

        corner: "topRight"
        thickness: win.tRight
        thicknessY: win.tTop
        shellScreen: win.screen
        enabled: !win.fullscreen
        minHeight: 420
        components: win.cornerPopouts
    }

    CornerPopout {
        id: bottomRight

        corner: "bottomRight"
        thickness: win.tRight
        thicknessY: win.tBottom
        shellScreen: win.screen
        enabled: !win.fullscreen
        minHeight: 420
        components: win.cornerPopouts
    }

    // Each edge's popout, for the widgets in its centre: out of the edge at
    // the widget.
    Repeater {
        model: BarLayout.edgeNames
        onItemAdded: (i, item) => win.edgePopouts = win.edgePopouts.concat([item])
        onItemRemoved: (i, item) => win.edgePopouts = win.edgePopouts.filter(d => d !== item)

        CornerPopout {
            required property string modelData
            // The centre region's icon pill it grows out of, if any.
            readonly property var pill: win.pillRect(modelData, "center")

            side: modelData
            pillLength: pill ? (vertical ? pill.width : pill.height) : 0
            pillAlong: pill ? (vertical ? pill.x + pill.width / 2 : pill.y + pill.height / 2) : -1
            thickness: pill ? Math.max(win.edgeThickness(modelData), vertical ? pill.height : pill.width) : win.edgeThickness(modelData)
            shellScreen: win.screen
            enabled: !win.fullscreen
            components: win.cornerPopouts
        }
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

        // Out of the top's centre unless the layout places it.
        readonly property var at: win.placeOf("settings", {
            edge: "top",
            along: 0.5,
            hoverZone: false
        })

        name: "settings"
        edge: at.edge
        corner: at.corner || "topRight"
        along: at.along
        thickness: at.thickness
        thicknessY: at.thicknessY
        shellScreen: win.screen
        enabled: !win.fullscreen
        hoverZone: at.hoverZone
        wantsKeyboard: true
        panelWidth: Math.max(vertical ? at.length : 0, Math.min(900, win.innerWidth - 160))
        panelHeight: (settingsLoader.item?.implicitHeight ?? 540) + Tokens.spacing.large * 2

        Loader {
            id: settingsLoader

            anchors.fill: parent
            anchors.margins: Tokens.spacing.large
            // Warm: built ahead (Prewarm) and kept made while closed (O4).
            property int turn: -1
            // Once made it stays made (the turn stays due).
            property bool made: false

            Component.onCompleted: turn = Prewarm.enlist("settings")
            active: settings.active || made || Prewarm.due(turn)
            asynchronous: !settings.active
            onLoaded: made = true
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
            // Warm: once opened, its content stays made while closed, so it
            // opens at once next time (ROADMAP O4). A heavy one says
            // "warm": false in its manifest and is let go on close.
            readonly property bool warm: modelData.warm ?? true
            property bool opened: false

            onActiveChanged: {
                if (active)
                    opened = true;
                else if (!warm)
                    Qt.callLater(gc);
            }
            // Where it opens: the layout's place for it, else its manifest's.
            readonly property var at: win.placeOf(modelData.name, modelData)

            parent: win.contentItem
            name: modelData.name
            managed: !modelData.openWhen
            // "openIf": the usual open, and the root's property too (the
            // switcher waits a beat). "overFullscreen": usable over a
            // fullscreen window.
            open: (!modelData.openIf || (instance?.[modelData.openIf] ?? false)) && (modelData.openWhen ? enabled && win.focusedHere && (instance?.[modelData.openWhen] ?? false) : enabled && ShellState.isOpen(name, screenName)) && !yieldTo.some(n => win.drawerOpen(n))
            edge: at.edge
            corner: at.corner || "bottomRight"
            along: at.along
            thickness: at.thickness
            thicknessY: at.thicknessY
            shellScreen: win.screen
            enabled: Plugins.isEnabled(modelData.plugin) && (modelData.overFullscreen === true || !win.fullscreen)
            hoverZone: at.hoverZone
            zoneLength: modelData.zoneLength ?? 0
            wantsKeyboard: modelData.keyboard ?? false
            // The manifest's width, never wider than the screen leaves room
            // for; "content" height follows the entry, springing as it
            // changes (a dashboard tab, say).
            // At least as long as the pill it grows out of.
            panelWidth: Math.max(vertical ? at.length : 0, modelData.width === "content" ? (pdLoader.item?.implicitWidth ?? 200) + pad * 2 : Math.min(modelData.width ?? 400, win.innerWidth - 160))
            panelHeight: Math.max(vertical ? 0 : at.length, modelData.height === "content" ? (pdLoader.item?.implicitHeight ?? 300) + pad * 2 : Math.min(modelData.height ?? 300, win.height - 120))

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
                // Built ahead (Prewarm's turn) and kept; built in the background
                // unless it's opening right now.
                property int turn: -1

                // Its place in the warm-up queue, taken once.
                Component.onCompleted: {
                    if (pd.warm)
                        turn = Prewarm.enlist(`drawer ${pd.name}`);
                }
                active: pd.active || (pd.warm && (pd.opened || Prewarm.due(turn)))
                asynchronous: !pd.active
                source: pd.modelData.url
                // Content that sizes itself can know the room it has.
                onLoaded: {
                    if (item && "availableWidth" in item)
                        item.availableWidth = Qt.binding(() => win.innerWidth);
                }
            }
        }

        onObjectAdded: (i, o) => win.pluginDrawers = win.pluginDrawers.concat([o])
        onObjectRemoved: (i, o) => win.pluginDrawers = win.pluginDrawers.filter(d => d !== o)
    }

    // A drawer's input region, or (`bulge`) a bar bulge's.
    component DrawerRegion: Region {
        required property int index
        property bool bulge: false
        readonly property rect r: bulge ? win.bulgeRegion(index) : win.drawerRegion(index)

        x: r.x
        y: r.y
        width: r.width
        height: r.height
        intersection: Intersection.Subtract
    }

    // The edit mode on the bar: drop zones beside every edge, over
    // everything but the dragged chip.
    Loader {
        anchors.fill: parent
        z: 3
        active: win.editingHere
        sourceComponent: BarEditor {
            tLeft: win.tLeft
            tTop: win.tTop
            tRight: win.tRight
            tBottom: win.tBottom
        }
    }

    // The shell's ink transition: this window's still (the frame, the bars,
    // every open panel) soaks away over the new look.
    InkStill {}
}
