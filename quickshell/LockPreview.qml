pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.plugins.lock
import qs.plugins.lock.themes.xianxia
import qs.services as Services

// The shell's lock (Cave Abode) in a window, for trying it out: LockContext's preview
// mode never touches PAM or the stats, any passcode unlocks ("wrong" fails),
// and Esc on an empty passcode closes the window.
//   quickshell -p ~/.local/share/nafeel-shell/quickshell/LockPreview.qml
ShellRoot {
    LockContext {
        id: lockCtx
        preview: true
        onReleased: Qt.quit()
        onPreviewExit: Qt.quit()
        Component.onCompleted: {
            configure(CaveAbode.timing);
            begin();
        }
    }

    FloatingWindow {
        title: "Cave Abode preview"
        implicitWidth: 1600
        implicitHeight: 900
        color: "black"
        onClosed: Qt.quit()

        XianxiaSurface {
            anchors.fill: parent
            ctx: lockCtx
            host: lockHost
        }

        ShellLockHost {
            id: lockHost
        }

        LockFrame {
            anchors.fill: parent
        }
    }
}
