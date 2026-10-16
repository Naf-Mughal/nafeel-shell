pragma Singleton

import QtQuick
import Quickshell
import Nafeel
import qs.services

// Paste into the app that has the keyboard back: what was just copied
// (Clipboard.copyText / activate) is sent with Ctrl+V once the frame has let
// go of the keyboard (a fixed wait sent it while the closing panel still held
// it: it pasted into the shell). As the clipboard popout does.
Singleton {
    id: root

    property bool pending: false
    property bool image: false

    // Call right after copying, and after closing the panel.
    function now(isImage: bool): void {
        image = isImage;
        pending = true;
        if (ShellState.keyboardHeld)
            fallback.restart();
        else
            release.restart();
    }

    function send(): void {
        fallback.stop();
        if (!pending)
            return;
        pending = false;
        Clipboard.pasteShortcut(image);
    }

    Connections {
        target: ShellState

        function onKeyboardReleased(): void {
            if (root.pending)
                release.restart();
        }
    }

    // The app takes the keyboard back a moment after the release.
    Timer {
        id: release

        interval: 60
        onTriggered: root.send()
    }

    Timer {
        id: fallback

        interval: 2000
        onTriggered: root.send()
    }
}
