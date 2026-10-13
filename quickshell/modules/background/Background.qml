pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
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
        // window covers it, or (unless allowed) the laptop is on battery.
        readonly property bool live: !ShellState.locked && !Umbriel.fullscreenOn(modelData.name, modelData.width, modelData.height) && (Wallpapers.settings.v.liveOnBattery || !Power.hasBattery || Power.charging)

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
        color: Colours.palette.m3surface
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "nafeel-wallpaper"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None


        WallSlot {
            id: a

            anchors.fill: parent
            decode: win.decode
            visible: win.front === 0
            playing: visible && win.live
            onSettled: win.loaded(a)
        }

        WallSlot {
            id: b

            anchors.fill: parent
            decode: win.decode
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
            if (spare.path && spare.path !== shows)
                spare.path = "";
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

        InkStill {}
    }
}
