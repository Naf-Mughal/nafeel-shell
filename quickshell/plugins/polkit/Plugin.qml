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
//   qs -p <shell> ipc call polkit preview    (a pretend request: "wrong" is
//                                             refused, anything else granted;
//                                             no PAM, no XP)

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
import qs.services
import "../lock"
import "../lock/themes/xianxia"

Scope {
    id: root

    readonly property alias agent: agent
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

    onShowingChanged: ShellState.takeover = showing ? screenName : ""

    function _start(): void {
        if (showing)
            return;
        screenName = Umbriel.focusedOutput || (Quickshell.screens[0]?.name ?? "");
        lockCtx.preview = preview;
        lockCtx.failures = 0;
        lockCtx.reward = null;
        lockCtx.buffer = "";
        lockCtx.cells = 0;
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
}
