pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Nafeel
import qs.services
import qs.plugins.lock.themes.xianxia

// The session's entrance: the login screen carried on into the session.
// SDDM ends its greeter the moment the password is accepted (the grant never
// played) and umbriel starts on a blank screen; the shell took ~1.75 s from
// there to its wallpaper, then built its panels in view. So the first thing
// the shell draws is the login screen as it was left (the cave abode,
// verifying, over the wallpaper's still), everything else loads behind it,
// and once the wallpaper is up the grant plays and the ink recedes into the
// desktop.
//
// shell.qml loads it first at the session's start (bin/nafeel-shell sets
// NAFEEL_ENTRANCE for the first shell of a umbriel session; never after a
// reload) and plays it; before it's even made, Splash.qml shows a picture of
// its first frame, which it keeps (`coverFile`) for the next login. Bare:
// no words, so the picture never shows a stale time. IPC `entrance play`
// shows it again (to look at it, or measure it). Shell-only: not in
// bin/nafeel-greeter's list.
Scope {
    id: root

    // Set by shell.qml once everything behind the entrance is made.
    property bool desktopMade: false

    property bool shown: false
    // Its first frame (with the wallpaper's painting) is on screen: the
    // splash can go and the rest of the shell load (shell.qml).
    property bool drawn: false
    // Where the picture of that frame is kept for the next login, and
    // whether it's there already (Splash.qml showed it).
    property string coverFile: ""
    property bool coverKnown: false
    // When it came up (the log line says how long the desktop took).
    property double shownAt: 0


    // What the login screen showed (GreeterExport's GreeterData.qml: its
    // palette, type and picture), read at once: the shell's own settings
    // and palette come ~1 s into the start, and the surface jumped to them.
    readonly property string greeterDir: Quickshell.env("HOME") + "/.local/state/nafeel-shell/greeter"
    // Who had the theme's host before (Xian is shared with the lock and the
    // polkit prompt): theirs again once the entrance is over.
    property var hostBefore: null

    function readGreeter(): void {
        entranceHost.data?.destroy();
        entranceHost.data = null;
        const c = Qt.createComponent(`file://${greeterDir}/GreeterData.qml?${Date.now()}`);
        if (c.status === Component.Ready)
            entranceHost.data = c.createObject(root);
    }

    function play(): void {
        if (shown)
            return;
        readGreeter();
        hostBefore = Xian.host;
        Xian.host = entranceHost;
        entranceCtx.configure(CaveAbode.timing);
        // Still until the grant: the shell's services start on this thread
        // meanwhile (~1 s with no frames to spare), so motion would hitch.
        entranceCtx.ambient = false;
        entranceCtx.phase = "verifying";
        entranceCtx.poke();
        shownAt = Date.now();
        drawn = false;
        shown = true;
        ShellState.entering = true;
        deadline.restart();
    }

    function open(): void {
        if (!shown || entranceCtx.phase !== "verifying")
            return;
        deadline.stop();
        console.info(`entrance: desktop ready after ${Date.now() - shownAt} ms`);
        entranceCtx.ambient = true;
        entranceCtx.enter();
    }

    function finish(): void {
        shown = false;
        if (Xian.host === entranceHost)
            Xian.host = hostBefore;
        hostBefore = null;
        ShellState.entering = false;
        // A fresh context for the next play (IPC).
        entranceCtx.phase = "intro";
    }

    // The desktop is up (a wallpaper on screen, the frame made): a couple of
    // frames for it to draw under the cover, then the grant.
    readonly property bool desktopUp: desktopMade && ShellState.desktopShown
    onDesktopUpChanged: if (desktopUp && shown) settle.restart()

    Timer {
        id: settle

        interval: 120
        onTriggered: root.open()
    }

    // Whatever happens behind, the desktop is never kept waiting long.
    Timer {
        id: deadline

        interval: 4000
        onTriggered: {
            console.warn("entrance: the desktop wasn't ready in time; opening anyway");
            root.open();
        }
    }

    // Replays it (the desktop is already up: straight through).
    IpcHandler {
        target: "entrance"

        function play(): void {
            root.play();
            if (root.desktopUp)
                settle.restart();
        }
    }

    EntranceHost {
        id: entranceHost

        dir: root.greeterDir
    }

    LockContext {
        id: entranceCtx

        // Never touches PAM or the stats.
        preview: true
        onReleased: root.finish()
    }

    Variants {
        model: root.shown ? Quickshell.screens : []

        PanelWindow {
            id: win

            required property ShellScreen modelData

            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "nafeel-entrance"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            // Never in the way: clicks go to the desktop under it.
            mask: Region {}

            // The surface as one picture, so the reveal can cut it away.
            Item {
                id: picture

                anchors.fill: parent
                // Whole: not before the wallpaper's painting is in (unless
                // it's slow), so it never pops in over bare ink.
                visible: surface.backdropReady || backdropWait.waited
                layer.enabled: true
                layer.effect: ShaderEffect {
                    property real itemWidth: picture.width
                    property real itemHeight: picture.height
                    property real progress: surface.dissolve
                    property real inward: surface.inward ? 1 : 0
                    property point origin: Qt.point(0.5, surface.formationY / Math.max(1, picture.height))
                    property color goldColor: Xian.gold

                    fragmentShader: Qt.resolvedUrl("../../shaders/entrance_reveal.frag.qsb")
                }

                XianxiaSurface {
                    id: surface

                    anchors.fill: parent
                    ctx: entranceCtx
                    host: entranceHost
                    still: true
                    bare: true
                    // No desktop to grab: a clear one, so the outro's own
                    // dissolve draws nothing and the reveal above does it.
                    shot: Qt.resolvedUrl("../../assets/clear.png")
                }
            }

            Timer {
                id: backdropWait

                property bool waited: false

                running: true
                interval: 400
                onTriggered: waited = true
            }

            // Its first frame on screen with the picture: kept for the next
            // login's splash (the first screen's), then the rest may load.
            Connections {
                target: picture.Window.window

                function onFrameSwapped(): void {
                    if (root.drawn || !picture.visible)
                        return;
                    if (root.coverFile && !root.coverKnown && win.modelData === Quickshell.screens[0])
                        win.keep();
                    root.drawn = true;
                }
            }

            function keep(): void {
                const r = win.modelData.devicePixelRatio || 1;
                const file = root.coverFile;
                picture.grabToImage(result => {
                    if (result.saveToFile(file)) {
                        root.coverKnown = true;
                        // Earlier logins' pictures (of a look that's gone).
                        Quickshell.execDetached(["sh", "-c", 'for f in "$1"/entrance-*.jpg; do [ "$f" = "$2" ] || rm -f "$f"; done', "sh", root.greeterDir, file]);
                    }
                }, Qt.size(Math.round(picture.width * r), Math.round(picture.height * r)));
            }

            // Paced at the vblanks like the shell's other windows.
            Item {
                readonly property var quickWindow: Window.window
                onQuickWindowChanged: {
                    if (quickWindow)
                        FramePacer.attach(quickWindow);
                }
            }
        }
    }
}
