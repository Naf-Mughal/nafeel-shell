import QtQuick
import Quickshell
import Quickshell.Wayland

// The session entrance's first frame, at once. Made before anything else of
// the shell is even compiled (it imports nothing of it): a picture of the
// entrance's cover as the last login drew it (plugins/lock/Entrance.qml keeps
// it), for the look the login screen has now (GreeterExport's
// GreeterData.qml: palette, type, wallpaper). There in ~0.5 s where the
// entrance's own first frame took ~1.7 s; it gives way once that frame is up.
// When the look changed (or the first time), there's no picture: no splash.
Scope {
    id: root

    property bool active: false
    // Its first frame is on screen (the entrance starts loading then: made
    // alongside, it held this one back).
    property bool drawn: false
    readonly property string dir: Quickshell.env("HOME") + "/.local/state/nafeel-shell/greeter"
    // The picture for the look as it is now, and whether it's there.
    property string file: ""
    readonly property bool known: file !== "" && probe.status === Image.Ready

    // A key of what the cover shows (not what it doesn't, as the cultivation).
    function keyOf(data: var): string {
        let w = 0, h = 0;
        for (const s of Quickshell.screens) {
            const r = s.devicePixelRatio || 1;
            if (s.width * r * s.height * r > w * h) {
                w = Math.round(s.width * r);
                h = Math.round(s.height * r);
            }
        }
        return Qt.md5(JSON.stringify([data.m3, data.follow, data.wallpaperSource, data.wallpaperStill, data.paperFibre, data.paperInk, data.paperFill, data.fontCjk, data.fontSerif, w, h]));
    }

    Component.onCompleted: {
        const c = Qt.createComponent(`file://${dir}/GreeterData.qml?${Date.now()}`);
        if (c.status !== Component.Ready)
            return;
        const data = c.createObject(root);
        if (!data)
            return;
        file = `${dir}/entrance-${keyOf(data)}.jpg`;
        data.destroy();
    }

    // Decoded here, once (a screen-sized JPEG: ~30 ms), so the window's first
    // frame has it; only known if it's there.
    Image {
        id: probe

        visible: false
        source: root.file ? "file://" + root.file : ""
        asynchronous: false
        cache: true
    }

    Variants {
        model: root.active && root.known ? Quickshell.screens : []

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
            WlrLayershell.namespace: "nafeel-entrance"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {}

            Image {
                id: picture

                anchors.fill: parent
                source: probe.source
                cache: true
                fillMode: Image.PreserveAspectCrop
            }

            Connections {
                target: picture.Window.window

                function onFrameSwapped(): void {
                    root.drawn = true;
                }
            }
        }
    }
}
