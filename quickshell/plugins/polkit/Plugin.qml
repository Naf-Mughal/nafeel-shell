// The polkit plugin's root: the shell's polkit agent (authentication
// prompts). While a request is up `active` is true and the manifest's drawer
// (PolkitPrompt) opens by itself on the focused screen; switched off, the
// shell has no agent. A granted request is cultivation too (the lock's XP,
// a little), and the prompt stays a beat to show it.

import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import "../lock"

Scope {
    id: root

    readonly property alias agent: agent
    readonly property var flow: agent.flow
    readonly property bool active: (agent.isActive && flow !== null) || granted
    // Bumped on a wrong password, so the prompt can shake.
    property int failures: 0
    // This request's wrong passwords.
    property int misses: 0
    // Granted, showing the gain: { total, levelBefore, levelAfter } | null.
    property bool granted: false
    property var gain: null

    onFlowChanged: if (flow)
        misses = 0

    PolkitAgent {
        id: agent

        onIsRegisteredChanged: console.info(`polkit: agent ${isRegistered ? "registered" : "not registered"}`)
    }

    Connections {
        target: root.flow

        function onAuthenticationFailed(): void {
            root.failures++;
            root.misses++;
        }

        function onAuthenticationSucceeded(): void {
            const lines = [{
                    label: "AUTHORISED",
                    xp: 5
                }];
            if (root.misses === 0)
                lines.push({
                    label: "FLAWLESS",
                    xp: 3
                });
            root.gain = LockStats.award(lines);
            root.granted = true;
            linger.restart();
        }
    }

    Timer {
        id: linger

        interval: 1300
        onTriggered: root.granted = false
    }
}
