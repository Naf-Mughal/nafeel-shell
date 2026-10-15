// The polkit plugin's root: the shell's polkit agent. A request shows as the
// lock's sealing formation floating in the centre of the focused screen
// (PolkitPrompt): typed straight in like the lock, no field. A granted
// request is cultivation too (the lock's XP, a little), and the formation
// stays a beat to show it. Switched off, the shell has no agent.
//
//   qs -p <shell> ipc call polkit preview    (a pretend request: "wrong"
//                                             is refused, anything else is
//                                             granted, no XP; Esc ends it)

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Polkit
import qs.services
import "../lock"

Scope {
    id: root

    readonly property alias agent: agent
    readonly property var flow: agent.flow
    readonly property bool asking: (agent.isActive && flow !== null) || preview
    readonly property bool active: asking || granted
    // Bumped on a wrong password.
    property int failures: 0
    // This request's wrong passwords.
    property int misses: 0
    // Granted, showing the gain: { total, levelBefore, levelAfter } | null.
    property bool granted: false
    property var gain: null
    // A pretend request (IPC preview), for looking at it.
    property bool preview: false
    // Waiting on polkit's answer.
    property bool weighing: false

    onFlowChanged: if (flow) {
        misses = 0;
        weighing = false;
    }

    function submit(text: string): void {
        if (text === "" || weighing)
            return;
        weighing = true;
        if (preview) {
            demo.accept = text.toLowerCase() !== "wrong";
            demo.restart();
        } else {
            flow?.submit(text);
        }
    }

    function cancel(): void {
        if (preview)
            preview = false;
        else
            flow?.cancelAuthenticationRequest();
        weighing = false;
    }

    function _failed(): void {
        weighing = false;
        failures++;
        misses++;
    }

    function _succeeded(award: bool): void {
        weighing = false;
        const lines = [{
                label: "AUTHORISED",
                xp: 5
            }];
        if (misses === 0)
            lines.push({
                label: "FLAWLESS",
                xp: 3
            });
        gain = award ? LockStats.award(lines) : {
            total: lines.reduce((a, l) => a + l.xp, 0),
            levelBefore: LockStats.level,
            levelAfter: LockStats.level
        };
        granted = true;
        preview = false;
        linger.restart();
    }

    PolkitAgent {
        id: agent

        onIsRegisteredChanged: console.info(`polkit: agent ${isRegistered ? "registered" : "not registered"}`)
    }

    Connections {
        target: root.flow

        function onAuthenticationFailed(): void {
            root._failed();
        }

        function onAuthenticationSucceeded(): void {
            root._succeeded(true);
        }
    }

    Timer {
        id: demo

        property bool accept
        interval: 700
        onTriggered: accept ? root._succeeded(false) : root._failed()
    }

    Timer {
        id: linger

        interval: 1500
        onTriggered: root.granted = false
    }

    IpcHandler {
        target: "polkit"

        function preview(): void {
            root.misses = 0;
            root.granted = false;
            root.preview = true;
        }
        function cancel(): void {
            root.cancel();
        }
    }

    // The formation, on the focused screen (kept while it fades out).
    Variants {
        model: prompt.shown ? Quickshell.screens.filter(s => s.name === Umbriel.focusedOutput || (Umbriel.focusedOutput === "" && s === Quickshell.screens[0])).slice(0, 1) : []

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
            WlrLayershell.namespace: "nafeel-shell-polkit"
            WlrLayershell.keyboardFocus: root.asking ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            PolkitPrompt {
                anchors.fill: parent
                polkit: root
                fade: prompt.fade
            }
        }
    }

    // Fading in and out (the window outlives `active` while it fades).
    Item {
        id: prompt

        property real fade: root.active ? 1 : 0
        readonly property bool shown: root.active || fade > 0.001

        Behavior on fade {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutCubic
            }
        }
    }
}
