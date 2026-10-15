// The polkit plugin's root: the shell's polkit agent. A request shows as the
// lock itself, compact (XianxiaSurface): its formation, prompt and seals
// floating over the desktop on the focused screen, typed into as the lock
// is, with the lock's lives and seclusion (faillock's tally, shared). Granted:
// the 开 seal breaks it open and the cultivation earned shows (the lock's
// XP, a little). A wrong incantation: qi deviation, and the request is
// dismissed. Esc leaves. Switched off, the shell has no agent.
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
    // The lock's context the panel's surface reads (PolkitPrompt).
    readonly property alias ctx: lockCtx
    readonly property var flow: agent.flow
    // A pretend request (IPC preview).
    property bool preview: false
    // Whether the formation is up (it outlives the request through the seal
    // breaking, or the deviation).
    property bool showing: false
    readonly property bool active: showing

    function _start(): void {
        lockCtx.preview = preview;
        lockCtx.failures = 0;
        lockCtx.reward = null;
        lockCtx.buffer = "";
        lockCtx.cells = 0;
        lockCtx.begin();
        showing = true;
    }

    // Ends the request (cancelled, or after a wrong one) and lets go.
    function _dismiss(): void {
        if (!preview && flow && !flow.isCompleted)
            flow.cancelAuthenticationRequest();
        preview = false;
        showing = false;
    }

    PolkitAgent {
        id: agent

        onIsRegisteredChanged: console.info(`polkit: agent ${isRegistered ? "registered" : "not registered"}`)
        onAuthenticationRequestStarted: root._start()
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
        onReleased: root.showing = false
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
        function onAuthenticationRequestCancelled(): void {
            if (lockCtx.phase !== "granted" && lockCtx.phase !== "exiting")
                root.showing = false;
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
    }

}
