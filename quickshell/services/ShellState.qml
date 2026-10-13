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
import qs.config

Singleton {
    id: root

    property string pinned: ""
    // Panels in motion (each Drawer counts itself while it springs open or
    // shut): work that can wait (Umbriel's window list) waits for 0, so a
    // panel's animation never shares its frames with it.
    property int moving: 0
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
        previewed = name;
        screen = screenName;
    }

    // Close a hover preview unless the pointer comes back (to the drawer or
    // its trigger) within closeDelay.
    function unpreviewLater(name: string): void {
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
        closeTimer.stop();
        inTick.stop();
        closeAll = false;
        pinned = name;
        previewed = "";
        screen = screenName;
    }

    function close(): void {
        closeTimer.stop();
        if (pinned === "" && previewed === "")
            return;
        closeAll = true;
        inTick.restart();
    }

    // A close lands inside an animation step (the vblank-paced driver's,
    // Nafeel's FramePacer), after three refreshes of still frames
    // (FrameWindow's pump draws them). Applied between refreshes it drew a
    // frame out of step; and umbriel shows the first frame after a rest at
    // once but the next one on its own vblank schedule, a refresh later: the
    // still frames take that refresh, the panel's motion starts in step.
    property bool closeAll: false
    readonly property bool closePending: inTick.running

    NumberAnimation {
        id: inTick

        duration: 45
        onFinished: {
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
    onRestingChanged: {
        if (resting)
            idleCollect.restart();
        else
            idleCollect.stop();
    }

    Connections {
        target: Prewarm

        function onDoneChanged(): void {
            if (Prewarm.done && root.resting)
                idleCollect.restart();
        }
    }

    Timer {
        id: delayedClose

        onTriggered: root.close()
    }

    Timer {
        id: idleCollect

        interval: 1500
        onTriggered: {
            if (root.resting)
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
