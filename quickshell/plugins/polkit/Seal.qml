import QtQuick
import Quickshell
import qs.services
import "../lock"
import "../lock/themes/xianxia"

// The polkit request in the frame window (an overlay), under everything the
// frame draws, so the bars and the frame's corners sit over its edges as
// they do over the desktop: the lock's surface, compact, while a request is
// up on this screen.
Item {
    id: root

    property ShellScreen shellScreen
    readonly property var polkit: Plugins.instance("polkit")
    readonly property bool here: (polkit?.showing ?? false) && polkit.screenName === (shellScreen?.name ?? "")

    anchors.fill: parent
    z: -1

    ShellLockHost {
        id: lockHost
    }

    // Where the keyboard is once it's up (the log: Esc and typing need it).
    Timer {
        running: root.here
        interval: 1500
        onTriggered: console.info(`polkit: keyboard at ${root.Window.window?.activeFocusItem}, window active ${root.Window.window?.active}`)
    }

    Loader {
        anchors.fill: parent
        active: root.here
        sourceComponent: XianxiaSurface {
            compact: true
            ctx: root.polkit.ctx
            host: lockHost
            shot: root.polkit.capture?.urlFor(root.shellScreen) ?? ""
            idleLine: root.polkit.preview ? "A pretend request: “wrong” is refused, anything else granted" : (root.polkit.flow?.message ?? "") + ((root.polkit.flow?.identities?.length ?? 0) > 1 ? `  ·  as ${root.polkit.flow.selectedIdentity?.displayName || root.polkit.flow.selectedIdentity?.name || ""}` : "")
        }
    }
}
