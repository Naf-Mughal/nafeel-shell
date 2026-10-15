// The polkit plugin's root: the shell's polkit agent. A request shows as the
// lock itself (XianxiaSurface, compact: no title, hour, cultivator, music,
// tokens or insights) inside the frame on the focused screen (Seal.qml, the
// frame window's overlay, under the bars, so it merges with them): the
// desktop, grabbed first, soaks into ink, the formation turns, typed into
// as the lock is, with the lock's rounds and seclusion (faillock's tally,
// shared). Granted: the 开 seal breaks it open, the cultivation earned shows
// (the lock's XP, a little) and the ink recedes. A wrong incantation: qi
// deviation, and the request is dismissed. Esc leaves. Switched off, the
// shell has no agent.
//
// Its other style (Settings → Authentication: "Floating"): the formation
// and its prompt alone, floating over the desktop on a pool of ink, in its
// own window above everything; nothing grabbed, nothing soaked.
//
//   qs -p <shell> ipc call polkit preview    (a pretend request: "wrong" is
//                                             refused, anything else granted;
//                                             no PAM, no XP)

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Polkit
import qs.config
import qs.services
import "../lock"
import "../lock/themes/xianxia"

Scope {
    id: root

    readonly property alias agent: agent

    readonly property SettingsPage settings: SettingsPage {
        name: "polkit"
        title: "Authentication"
        gloss: "授权"
        icon: "admin_panel_settings"
        order: 60
        description: "How an admin action asks for your password."

        SettingItem {
            key: "polkit.style"
            icon: "style"
            label: "Style"
            description: "Lock: the lock itself inside the frame, the screen soaking into ink. Floating: the formation alone over the desktop on a pool of ink."
            def: "lock"
            options: [
                {
                    value: "lock",
                    icon: "lock",
                    label: "Lock"
                },
                {
                    value: "floating",
                    icon: "bubble_chart",
                    label: "Floating"
                }
            ]
        }
    }
    readonly property bool floating: settings.v["polkit.style"] === "floating"
    // The style of the request that's up (a change waits for the next).
    property bool floatingNow: false
    readonly property alias ctx: lockCtx
    // The request being answered (kept: the agent lets go of its flow the
    // moment it completes, before a success could be heard through it).
    property var flow: null
    // A pretend request (IPC preview).
    property bool preview: false
    // Up, on this screen (it outlives the request through the seal breaking
    // and the ink receding, or the deviation).
    property bool showing: false
    property string screenName: ""
    // The desktop as it was, for the ink to soak (and recede back to).
    readonly property var capture: grab.item

    onShowingChanged: ShellState.takeover = showing && !floatingNow ? screenName : ""

    function _start(): void {
        if (showing)
            return;
        screenName = Umbriel.focusedOutput || (Quickshell.screens[0]?.name ?? "");
        lockCtx.preview = preview;
        lockCtx.failures = 0;
        lockCtx.reward = null;
        lockCtx.buffer = "";
        lockCtx.cells = 0;
        floatingNow = floating;
        // Floating: nothing to soak, up at once.
        if (floatingNow) {
            _show();
            return;
        }
        // Grab the screen first, then show (a beat at most).
        grab.active = false;
        grab.active = true;
        showAnyway.restart();
    }

    function _show(): void {
        showAnyway.stop();
        if (showing)
            return;
        lockCtx.configure(CaveAbode.timing);
        lockCtx.begin();
        showing = true;
    }

    // Ends the request (Esc, or after a wrong one): the ink recedes as the
    // lock's does, then it lets go (lockCtx.released).
    function _dismiss(): void {
        if (!preview && flow && !flow.isCompleted)
            flow.cancelAuthenticationRequest();
        if (showing && lockCtx.phase !== "exiting")
            lockCtx._exit();
        else if (!showing)
            preview = false;
    }

    PolkitAgent {
        id: agent

        onIsRegisteredChanged: console.info(`polkit: agent ${isRegistered ? "registered" : "not registered"}`)
        onAuthenticationRequestStarted: {
            root.preview = false;
            root.flow = agent.flow;
            root._start();
        }
    }

    Loader {
        id: grab

        active: false
        sourceComponent: ScreenCapture {
            onFinished: root._show()
        }
    }

    Timer {
        id: showAnyway

        interval: 450
        onTriggered: root._show()
    }

    // The lock's context, answered by polkit (or the pretend verdict).
    LockContext {
        id: lockCtx

        smallReward: true
        answer: response => {
            if (root.preview) {
                demo.accept = response.toLowerCase() !== "wrong";
                demo.restart();
            } else {
                root.flow?.submit(response);
            }
        }
        onDenied: dismissAfter.restart()
        onReleased: {
            root.showing = false;
            root.preview = false;
            grab.active = false;
        }
        onLeaveRequested: root._dismiss()
    }

    Connections {
        target: root.flow

        function onAuthenticationFailed(): void {
            lockCtx.verdict(false);
        }
        function onAuthenticationSucceeded(): void {
            lockCtx.verdict(true);
        }
        function onIsCompletedChanged(): void {
            if (root.flow.isSuccessful)
                lockCtx.verdict(true);
        }
        function onAuthenticationRequestCancelled(): void {
            if (lockCtx.phase !== "granted" && lockCtx.phase !== "exiting")
                root._dismiss();
        }
    }

    Timer {
        id: demo

        property bool accept
        interval: 700
        onTriggered: lockCtx.verdict(accept)
    }

    // A wrong one: the deviation plays, then the request goes.
    Timer {
        id: dismissAfter

        interval: Xian.d(1300)
        onTriggered: root._dismiss()
    }

    IpcHandler {
        target: "polkit"

        function preview(): void {
            root.preview = true;
            root.flow = null;
            root._start();
        }
        function cancel(): void {
            root._dismiss();
        }
        // Offer `text` to the pretend request (tests; never a real one).
        function previewSubmit(text: string): void {
            if (root.preview) {
                lockCtx.buffer = text;
                lockCtx.submit();
            }
        }
        // What the formation is doing (tests).
        function state(): string {
            return `${root.showing} ${lockCtx.phase} ${lockCtx.ambient} ${lockCtx.ambientTime.toFixed(1)}`;
        }
    }

    // Floating: its own window over everything on the focused screen.
    Variants {
        model: root.showing && root.floatingNow ? Quickshell.screens.filter(s => s.name === root.screenName).slice(0, 1) : []

        PanelWindow {
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
            // Not "nafeel-shell…": the frosted-paper rule would blur behind
            // the pool of ink, edged where it turns 5% opaque.
            WlrLayershell.namespace: "nafeel-polkit"
            WlrLayershell.keyboardFocus: lockCtx.phase === "exiting" ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive

            XianxiaSurface {
                anchors.fill: parent
                compact: true
                floating: true
                ctx: lockCtx
                host: floatHost
                idleLine: root.preview ? "A pretend request: “wrong” is refused, anything else granted" : (root.flow?.message ?? "") + ((root.flow?.identities?.length ?? 0) > 1 ? `  ·  as ${root.flow.selectedIdentity?.displayName || root.flow.selectedIdentity?.name || ""}` : "")
            }
        }
    }

    ShellLockHost {
        id: floatHost
    }
}
