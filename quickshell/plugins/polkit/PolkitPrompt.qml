import QtQuick
import qs.services
import "../lock"
import "../lock/themes/xianxia"

// The polkit request's panel: grown out of the bottom edge to the whole
// screen between the bars, on the shell's paper (the frame's own, frosted as
// every panel), with the lock's surface on it, compact and without its pool
// of ink: formation, prompt, seals, typed into as the lock is.
Item {
    id: root

    readonly property var polkit: Plugins.instance("polkit")

    ShellLockHost {
        id: lockHost
    }

    XianxiaSurface {
        anchors.fill: parent
        visible: root.polkit !== null
        compact: true
        pool: false
        ctx: root.polkit?.ctx ?? null
        host: lockHost
        idleLine: root.polkit?.preview ? "A pretend request: “wrong” is refused, anything else granted" : (root.polkit?.flow?.message ?? "") + ((root.polkit?.flow?.identities?.length ?? 0) > 1 ? `  ·  as ${root.polkit.flow.selectedIdentity?.displayName || root.polkit.flow.selectedIdentity?.name || ""}` : "")
    }
}
