pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.plugins.lock.themes.xianxia

// The lock as it looks, without locking (ipc lock preview): the screen
// grabbed, then the whole lock surface over it on the focused screen, in
// LockContext's demo mode ("wrong" is refused, anything else unlocks;
// nothing saved). Esc on an empty passcode, or the unlock, ends it.
Scope {
    id: root

    signal finished

    readonly property string screenName: Umbriel.focusedOutput || (Quickshell.screens[0]?.name ?? "")
    property bool shown: false

    function show(): void {
        if (shown)
            return;
        ctx.configure(CaveAbode.timing);
        ctx.begin();
        shown = true;
    }

    function submit(text: string): void {
        ctx.buffer = text;
        ctx.submit();
    }

    ShellLockHost {
        id: lockHost
    }

    LockContext {
        id: ctx

        preview: true
        onReleased: root.finished()
        onPreviewExit: root.finished()
    }

    ScreenCapture {
        id: capture

        onFinished: root.show()
    }

    Timer {
        interval: 450
        running: true
        onTriggered: root.show()
    }

    Variants {
        model: root.shown ? Quickshell.screens.filter(s => s.name === root.screenName).slice(0, 1) : []

        PanelWindow {
            id: win

            required property ShellScreen modelData

            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "black"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "nafeel-lock-preview"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            XianxiaSurface {
                anchors.fill: parent
                ctx: ctx
                host: lockHost
                shot: capture.urlFor(win.modelData)
            }
        }
    }
}
