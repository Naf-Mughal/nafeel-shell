pragma Singleton

// Which drawer is open, on which screen, and how it got there:
//
//   previewed  opened by hover (a bar icon, a frame hot zone, the drawer
//              itself); closes a moment after the pointer leaves
//   pinned     opened by a click (on its trigger or inside it) or a keybind;
//              stays until an outside click, Esc, or close(). A pinned bar
//              panel moves with the hover to other bar icons (a menu bar);
//              any other pinned drawer can't be replaced by hover.
//
// IPC, for keybinds (drawer names: see the Drawer instances):
//
//   qs -p <shell> ipc call shell toggle <drawer>    (bar panels: bar:sound, bar:connect, …)
//   qs -p <shell> ipc call shell open <drawer>
//   qs -p <shell> ipc call shell close
//   qs -p <shell> ipc call shell command <tab>     (command center: home, apps, …)
//   qs -p <shell> ipc call shell search <text>     (launcher with text typed)

import QtQuick
import Quickshell
import Quickshell.Io
import Nafeel
import qs.config

Singleton {
    id: root

    property string pinned: ""
    // Panels in motion (each Drawer counts itself while it springs open or
    // shut): work that can wait (Umbriel's window list) waits for 0, so a
    // panel's animation never shares its frames with it.
    property int moving: 0
    // For measuring (NAFEEL_PRESENT_LOG): where the motion ends.
    onMovingChanged: if (moving === 0)
        FramePacer.mark("still")
    // The dashboard's tab (kept between openings).
    property string dashTab: "dash"
    // The dock's preview: the app whose windows show above the dock (its
    // app id, "" for none), on the screen `dockPreviewScreen`.
    property string dockPreview: ""
    property string dockPreviewScreen: ""

    // The Settings panel's page (a SettingsPage name).
    property string settingsPage: "appearance"
    // The lock is up (Lock.qml keeps this).
    property bool locked: false
    property string previewed: ""

    // The frame got the keyboard for a pinned drawer. A panel with a field
    // to type in takes it (and sets req.taken); otherwise the frame keeps it
    // so Esc closes. (Without this the frame took it first and the field
    // only worked after a click.)
    signal keyboardGranted(var req)
    // The frame window on `screen` holds the keyboard; released: it just let
    // go (the app under it has it again: auto-paste waits for this).
    property bool keyboardHeld: false
    signal keyboardReleased
    property string screen: ""

    // Where the bar popout points: the centre (in screen coordinates) of the
    // bar widget that opened it; a popout out of an edge (a centre widget's)
    // grows from there.
    property real anchor: 0
    property real anchorX: 0
    // The bar icon under the pointer ("" for none); an open popout's icon
    // shows as active only while no other icon is hovered.
    property string barHover: ""

    // Bar controls by popout key ("bar:sound" -> its BarControl), so a
    // popout opened over IPC can point at its icon.
    property var barControls: ({})

    // The command center's tab, and its search text (shared so a keybind can
    // open it on a tab, and typing on any tab lands in the launcher).
    property string ccTab: "home"
    property string ccQuery: ""
    // The connections panel's list: "wifi" | "bluetooth".
    property string connectTab: "wifi"
    // Bumped to ask the command center to focus its search field.
    property int ccFocus: 0

    // The Settings panel's Panels page.
    readonly property SettingsPage settings: SettingsPage {
        name: "panels"
        title: "Panels"
        gloss: "面板"
        icon: "dashboard_customize"
        order: 12
        description: "How panels open and close."

        SettingItem {
            key: "panels.closeDelay"
            kind: "number"
            label: "Close after leaving"
            description: "How long a panel opened by hovering waits before it closes once the pointer leaves."
            def: 250
            min: 0
            max: 1000
            step: 50
            unit: " ms"
        }
        SettingItem {
            key: "panels.scrollStep"
            kind: "number"
            label: "Scroll step"
            description: "How far one wheel notch scrolls a panel."
            def: 160
            min: 40
            max: 480
            step: 20
            unit: " px"
        }
        SettingItem {
            key: "switcher.revealDelay"
            kind: "number"
            section: "Window switcher"
            label: "Show after"
            description: "Holding Alt+Tab this long shows the switcher; a quicker tap just flips to the last window."
            def: 140
            min: 0
            max: 500
            step: 20
            unit: " ms"
        }
    }
    readonly property int closeDelay: settings.v["panels.closeDelay"]

    function anchorTo(name: string): void {
        const c = barControls[name];
        // (A control gone with its icon, hidden or moved, can't say.)
        if (c && typeof c.mapToItem === "function") {
            const p = c.mapToItem(null, c.width / 2, c.height / 2);
            anchor = p.y;
            anchorX = p.x;
        }
    }

    // The open drawer on a screen, or "".
    function current(screenName: string): string {
        if (screen !== screenName)
            return "";
        return pinned !== "" ? pinned : previewed;
    }

    function isOpen(name: string, screenName: string): bool {
        return screen === screenName && (pinned === name || (pinned === "" && previewed === name));
    }

    function isPinned(screenName: string): bool {
        return pinned !== "" && screen === screenName;
    }

    function preview(name: string, screenName: string): void {
        if (rehearsal) {
            rehearsalEnd.stop();
            rehearsal = false;
            grabbing = "";
        }
        if (pinned !== "" && pinned !== name) {
            // Bar panels behave like a menu bar: once one is pinned, hovering
            // another bar icon switches to it and the pin moves along. So
            // does a panel open out of an icon pill (the dashboard over the
            // pill's icons), as the dock does: hovering one of the pill's icons
            // switches to its panel.
            if ((pinned.startsWith("bar:") && name.startsWith("bar:")) || BarLayout.sharesPill(pinned, name)) {
                closeTimer.stop();
                inTick.stop();
                closeAll = false;
                pinned = name;
                previewed = "";
                screen = screenName;
            }
            return;
        }
        closeTimer.stop();
        inTick.stop();
        closeAll = false;
        // From closed, a hover preview takes the keyboard first too (see
        // pin): the compositor's re-arrangement and the clipboard offer that
        // comes with the keyboard (Qt reads it at once) land before the
        // motion, not on its first frames.
        if (pinned === "" && previewed === "") {
            if (grabbing === name)
                return;
            grabbing = name;
            grabPreview = true;
            screen = screenName;
            if (!grabTick.running)
                grabTick.start();
            return;
        }
        previewed = name;
        screen = screenName;
    }

    // Close a hover preview unless the pointer comes back (to the drawer or
    // its trigger) within closeDelay.
    function unpreviewLater(name: string): void {
        if (grabbing === name && grabPreview) {
            // Left before it opened: never mind.
            grabTick.stop();
            grabbing = "";
            grabPreview = false;
            return;
        }
        if (previewed === name)
            closeTimer.restart();
    }

    // The pointer is still on `name`'s drawer: cancel a pending close. (A
    // drawer that opened under the pointer gets no new "entered" when the
    // pointer leaves its trigger for the drawer, so movement keeps it open.)
    function keep(name: string): void {
        if (previewed === name)
            closeTimer.stop();
    }

    function pin(name: string, screenName: string): void {
        if (rehearsal) {
            rehearsalEnd.stop();
            rehearsal = false;
            grabbing = "";
        }
        closeTimer.stop();
        inTick.stop();
        closeAll = false;
        // From closed: the frame window takes the keyboard first (grabbing):
        // that makes umbriel re-arrange its layers and Qt redraws the window
        // synchronously on the GUI thread; done mid-open it took frames from
        // it. The panel's content is made live meanwhile (Drawer.preparing),
        // and it opens three refreshes later. Switching between
        // open panels, or one already grabbing, goes at once.
        if (pinned === "" && previewed === "") {
            grabbing = name;
            grabPreview = false;
            screen = screenName;
            if (!grabTick.running)
                grabTick.start();
            return;
        }
        commitPin(name, screenName);
    }

    function commitPin(name: string, screenName: string): void {
        grabTick.stop();
        settleTick.stop();
        if (grabPreview) {
            // A hover preview's grab done: it opens as a preview.
            grabPreview = false;
            grabbing = "";
            FramePacer.mark("open");
            previewed = name;
            screen = screenName;
            return;
        }
        if (pinned !== name)
            FramePacer.mark("open");
        grabbing = "";
        pinned = name;
        previewed = "";
        screen = screenName;
    }

    // The panel about to open (keyboard taken, motion not started).
    property string grabbing: ""
    // ...or only rehearsing: once after the warm-up, each panel's content is
    // drawn a few frames clipped to nothing (no keyboard, no motion), so its
    // glyphs, textures and pipelines exist before its first real open.
    property bool rehearsal: false
    function rehearse(name: string, screenName: string): bool {
        if (pinned !== "" || previewed !== "" || grabbing !== "")
            return false;
        rehearsal = true;
        grabbing = name;
        screen = screenName;
        rehearsalEnd.restart();
        return true;
    }
    Timer {
        id: rehearsalEnd

        interval: 120
        onTriggered: {
            if (root.rehearsal) {
                root.rehearsal = false;
                root.grabbing = "";
            }
        }
    }
    // ...as a hover preview (not pinned) once it opens.
    property bool grabPreview: false

    Connections {
        target: FramePacer

        function onExposed(): void {
        }
    }

    // Opens two refreshes after umbriel's configure for the grab has been
    // handled (the frame window exposed: Qt redraws for it at once, out of
    // step), so the motion starts on a settled pipeline; at most 150 ms on.
    NumberAnimation {
        id: grabTick

        duration: 50
        onFinished: {
            if (root.grabbing !== "")
                root.commitPin(root.grabbing, root.screen);
        }
    }
    NumberAnimation {
        id: settleTick

        duration: 30
        onFinished: {
            if (root.grabbing !== "")
                root.commitPin(root.grabbing, root.screen);
        }
    }

    function close(): void {
        closeTimer.stop();
        if (grabbing !== "") {
            grabTick.stop();
            grabbing = "";
            grabPreview = false;
        }
        if (pinned === "" && previewed === "")
            return;
        closeAll = true;
        inTick.restart();
    }

    // A close lands inside an animation step (the vblank-paced driver's,
    // Nafeel's FramePacer): applied between refreshes it drew a frame out of
    // step. (The frame window kept drawing while the panel was open, so the
    // step is in step with the display.)
    property bool closeAll: false
    readonly property bool closePending: inTick.running

    NumberAnimation {
        id: inTick

        duration: 1
        onFinished: {
            FramePacer.mark("close");
            root.letGo(root.closeAll);
            root.closeAll = false;
        }
    }

    // Set for the moment a panel's state changes to closed: the frame
    // windows take hold of the keyboard and input mask before it does (they
    // would flip to released and back: two surface commits, an extra frame).
    property bool closing: false

    function letGo(all: bool): void {
        closing = true;
        if (all)
            pinned = "";
        previewed = "";
        closing = false;
    }

    // The JS heap collected while nothing moves. Left to itself, a cycle
    // comes due when enough garbage has piled up, often while a panel opens
    // or closes, and its sweep is one 15-20 ms step: a dropped frame. A full
    // collection once a panel has closed and settled (and once the warm-up is
    // done) leaves the next one far off. Unseen: nothing animates then.
    readonly property bool resting: pinned === "" && previewed === "" && moving === 0
    // Also once a panel has opened and gone still: the pause can't show then
    // (nothing moves), and its close starts with a clean heap. Left for later,
    // a collection came due during a close now and then: its sweep held the
    // GUI thread past a refresh, a vblank with no new frame.
    readonly property bool still: moving === 0 && !inTick.running
    onStillChanged: {
        if (still)
            idleCollect.restart();
        else
            idleCollect.stop();
    }

    Connections {
        target: Prewarm

        function onDoneChanged(): void {
            if (Prewarm.done && root.still)
                idleCollect.restart();
        }
    }

    Timer {
        id: delayedClose

        onTriggered: root.close()
    }

    Timer {
        id: idleCollect

        interval: root.resting ? 1500 : 700
        onTriggered: {
            if (root.still)
                gc();
        }
    }

    Timer {
        id: closeTimer

        interval: root.closeDelay
        onTriggered: {
            if (root.previewed !== "" && !inTick.running)
                inTick.restart();
        }
    }

    IpcHandler {
        target: "shell"

        // Measuring on the running shell (bin/frame-cycle, bin/prim-cycle):
        // the present log to <path>, or "" to stop it.
        function frameLog(path: string): void {
            if (path)
                FramePacer.startLog(path);
            else
                FramePacer.stopLog();
        }

        function toggle(drawer: string): void {
            if (root.pinned === drawer) {
                root.close();
            } else {
                root.anchorTo(drawer);
                root.pin(drawer, Umbriel.focusedOutput);
            }
        }

        function open(drawer: string): void {
            root.anchorTo(drawer);
            root.pin(drawer, Umbriel.focusedOutput);
        }

        function close(): void {
            root.close();
        }

        // Close after `ms` (bin/frame-probe: a close not landing on the
        // frames where the IPC client process runs).
        function closeAfter(ms: int): void {
            delayedClose.interval = Math.max(1, ms);
            delayedClose.restart();
        }

        // Show a drawer as a hover preview (closes when the pointer leaves it,
        // never takes the keyboard): for testing panels without stealing
        // focus.
        // The dashboard's tab: dash | media | performance | weather.
        function dash(tab: string): void {
            root.dashTab = tab;
        }
        // Preview an app's windows above the dock ("" puts it away).
        function dockPreview(app: string): void {
            root.dockPreview = app;
            root.dockPreviewScreen = Umbriel.focusedOutput;
        }
        // The Settings panel's page (appearance, wallpaper, weather, …).
        function settings(page: string): void {
            root.settingsPage = page;
        }
        function peek(drawer: string): void {
            root.anchorTo(drawer);
            root.preview(drawer, Umbriel.focusedOutput);
        }

        // Quit cleanly (the supervisor starts it again): profilers
        // (bin/qml-profile) flush their trace on a clean exit.
        function quit(): void {
            Qt.quit();
        }

        // The open drawer on the focused screen ("" for none).
        function current(): string {
            return root.current(Umbriel.focusedOutput);
        }

        // The command center's launcher with `text` already typed.
        function search(text: string): void {
            root.ccTab = "apps";
            root.ccQuery = text;
            root.pin("command", Umbriel.focusedOutput);
            root.ccFocus++;
        }

        // The command center on a tab ("home", "apps", "media", …); "apps"
        // focuses the search. Toggles when it's already open on that tab.
        function command(tab: string): void {
            if (root.pinned === "command" && root.ccTab === tab) {
                root.close();
                return;
            }
            root.ccTab = tab || "home";
            root.ccQuery = "";
            root.pin("command", Umbriel.focusedOutput);
            root.ccFocus++;
        }
    }
}
