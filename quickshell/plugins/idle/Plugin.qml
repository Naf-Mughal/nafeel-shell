import QtQuick
import Quickshell

// The idle plugin's root: the idle manager (dim, lock, screen off, sleep;
// the Power & idle page's stages) and its warning fade. Off: nothing
// happens when you step away (the lock still locks on demand and before
// sleep; the battery's care is the kernel's Power).
Scope {
    id: root

    readonly property Idle idle: Idle {}

    GraceOverlay {
        idle: root.idle
    }
}
