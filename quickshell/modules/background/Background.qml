pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Nafeel
import qs.config
import qs.services
import qs.components

// The wallpaper, on every screen, under everything. It takes part in the
// shell's ink transition: a new wallpaper is decoded ahead ("wallpaper.preload"
// on the Bus; "wallpaper.loaded" once it's ready), swapped in under the
// window's InkStill when the change lands ("wallpaper.current"), and soaks
// through together with the new colours. Images are decoded at the screen's
// size, so a 6K wallpaper costs no more than the screen.
//
// The namespace stays clear of the frost rule (^nafeel-shell): the wallpaper
// is what the panels blur, it isn't blurred itself.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property ShellScreen modelData
        readonly property size decode: Qt.size(Math.round(width * (modelData.devicePixelRatio || 1)), Math.round(height * (modelData.devicePixelRatio || 1)))
        // The main wallpaper, and this screen's own over it ("" = none).
        property string main: ""
        property string own: ""
        readonly property string shows: own || main
        // Which slot is on screen; the other one decodes the next wallpaper.
        property int front: 0
        readonly property WallSlot shown: front === 0 ? a : b
        readonly property WallSlot spare: front === 0 ? b : a
        // A live wallpaper plays unless the screen is locked, a fullscreen
        // window covers it, (unless allowed) the laptop is on battery, or
        // windows cover nine tenths of it and the covered rule holds it
        // ("auto": on battery only; each frame shown costs the whole screen
        // recomposited, ~17% of this GPU). `held` (IPC) holds it for a measure.
        readonly property bool unplugged: Power.hasBattery && !Power.charging
        readonly property string coveredRule: Wallpapers.settings.v.liveCovered ?? "auto"
        readonly property bool holdCovered: coveredRule === "pause" || (coveredRule === "auto" && unplugged)
        readonly property bool covered: holdCovered && Umbriel.coverageOn(modelData.name, modelData.width, modelData.height) >= 0.9
        // Plays through panels opening and closing: held for them, the
        // wallpaper visibly stuttered.
        readonly property bool live: !ShellState.locked && !Umbriel.fullscreenOn(modelData.name, modelData.width, modelData.height) && (Wallpapers.settings.v.liveOnBattery || !unplugged) && !covered && !Wallpapers.held

        function url(path: string): string {
            return path ? "file://" + path : "";
        }

        screen: modelData
        anchors {
            left: true
            right: true
            top: true
            bottom: true
        }
        // Always with an alpha channel (a window made opaque stays opaque):
        // clear over a video the compositor shows under it.
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "nafeel-wallpaper"
        // The keyboard only while the desktop's menu is open (Esc, arrows).
        WlrLayershell.keyboardFocus: deskMenu.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None


        Rectangle {
            anchors.fill: parent
            visible: !win.shown.clear
            color: Colours.palette.m3surface
        }

        WallSlot {
            id: a

            anchors.fill: parent
            decode: win.decode
            maxFps: win.unplugged ? (Wallpapers.settings.v.liveBatteryFps ?? 0) : 0
            visible: win.front === 0
            playing: visible && win.live
            onSettled: win.loaded(a)
        }

        WallSlot {
            id: b

            anchors.fill: parent
            decode: win.decode
            maxFps: win.unplugged ? (Wallpapers.settings.v.liveBatteryFps ?? 0) : 0
            visible: win.front === 1
            playing: visible && win.live
            onSettled: win.loaded(b)
        }

        // The spare slot has something to show (or never will): say so (the
        // transition waits).
        function loaded(slot: WallSlot): void {
            if (slot === spare && (slot.ready || slot.failed))
                Bus.publish("wallpaper.loaded", {
                    path: slot.path,
                    output: win.modelData.name
                });
        }

        // Show `path` here: swap to the pre-decoded slot (under the ink, if
        // it's running), or load it (the first one, or one not preloaded).
        function show(path: string): void {
            if (shown.path === path)
                return;
            if (spare.path === path)
                front = 1 - front;
            else
                shown.path = path;
            // No ink running (reduced motion, the first one): let go now.
            if (!Ink.frozen && !Ink.capturing)
                Qt.callLater(release);
        }

        // Once a change has landed, the slot it came from lets go of its
        // picture (above all a video: two decoders at once stall).
        function release(): void {
            if (spare.path && spare.path !== shows) {
                spare.path = "";
                trimLater.restart();
            }
        }

        // What the old wallpaper's decoder freed goes back to the system
        // once it has stopped (glibc kept it: a live-to-picture change left
        // the shell ~60 MB heavier than one started on the picture).
        Timer {
            id: trimLater

            interval: 3000
            onTriggered: Memory.trim()
        }

        Subscribe {
            topic: "ink.finished"
            onReceived: win.release()
        }

        Subscribe {
            topic: "wallpaper.preload"
            onReceived: p => {
                // Meant for another screen, or this one shows its own.
                if (p.output ? p.output !== win.modelData.name : win.own !== "")
                    return;
                if (win.spare.path === p.path && win.spare.ready)
                    win.loaded(win.spare);
                else
                    win.spare.path = p.path;
            }
        }

        Subscribe {
            topic: "wallpaper.current"
            onReceived: p => {
                win.main = p.path;
                if (!win.own)
                    win.show(p.path);
            }
        }

        Subscribe {
            topic: `wallpaper.output.${win.modelData.name}`
            onReceived: p => {
                win.own = p.path ?? "";
                win.show(win.shows);
            }
        }

        InkStill {
            id: still

            // Known to the shell's FramePacer as the wallpaper: its video
            // paces itself to the refresh (MpvVideo), never held for a tick.
            readonly property var quickWindow: Window.window
            onQuickWindowChanged: {
                if (quickWindow)
                    FramePacer.attachWallpaper(quickWindow);
            }
        }

        // A right-click on the empty desktop: its menu, where it landed.
        Item {
            id: desk

            anchors.fill: parent

            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: p => deskMenu.popup(desk, p.position)
            }
        }

        DesktopMenu {
            id: deskMenu

            screenName: win.modelData.name

            function popup(item: Item, point: point): void {
                from = item;
                at = point;
                show();
            }
        }
    }
}
