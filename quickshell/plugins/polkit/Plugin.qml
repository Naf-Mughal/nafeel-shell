// The polkit plugin's root: the shell's polkit agent (authentication
// prompts). While a request is up `active` is true and the manifest's drawer
// (PolkitPrompt) opens by itself on the focused screen; switched off, the
// shell has no agent.

import QtQuick
import Quickshell
import Quickshell.Services.Polkit

Scope {
    id: root

    readonly property alias agent: agent
    readonly property var flow: agent.flow
    readonly property bool active: agent.isActive && flow !== null
    // Bumped on a wrong password, so the prompt can shake.
    property int failures: 0

    PolkitAgent {
        id: agent

        onIsRegisteredChanged: console.info(`polkit: agent ${isRegistered ? "registered" : "not registered"}`)
    }

    Connections {
        target: root.flow

        function onAuthenticationFailed(): void {
            root.failures++;
        }
    }
}
