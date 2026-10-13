pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// One of a screen's two wallpaper slots: a picture, or a live wallpaper (a
// video, looped, silent). `ready` once there's something to show (decoded, or
// a video's still frame), `failed` if it can't be; settled() either way. A
// video plays only while `playing`, outside the shell (MpvPaper, over this
// window), the still frame showing whenever it doesn't. It plays the file,
// or its 1080p / 720p copy (the live resolution setting).
Item {
    id: root

    property string path: ""
    // The screen's output, for the player.
    property string output: ""
    property size decode
    property bool playing: true
    readonly property bool isVideo: Wallpapers.isVideo(path)
    property bool ready: false
    property bool failed: false

    signal settled

    onPathChanged: {
        ready = false;
        failed = false;
    }

    function _done(ok: bool): void {
        if (ready || failed)
            return;
        ready = ok;
        failed = !ok;
        settled();
    }

    // A picture.
    Loader {
        anchors.fill: parent
        active: root.path !== "" && !Wallpapers.isVideo(root.path)
        sourceComponent: Image {
            source: "file://" + root.path
            sourceSize: root.decode
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true
            onStatusChanged: {
                if (status === Image.Ready)
                    root._done(true);
                else if (status === Image.Error)
                    root._done(false);
            }
        }
    }

    // A live wallpaper's still frame, under the player: what shows while it
    // starts, while it's stopped, and in a change's ink.
    Image {
        anchors.fill: parent
        visible: root.isVideo
        source: root.isVideo ? "file://" + Wallpapers.stillOf(root.path) : ""
        sourceSize: root.decode
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        onStatusChanged: {
            if (!root.isVideo)
                return;
            if (status === Image.Ready)
                root._done(true);
            else if (status === Image.Error)
                root._done(false);
        }
    }

    // A live wallpaper: played while this slot is on screen and `playing`
    // (not while the lock screen shows it).
    MpvPaper {
        output: root.output
        path: root.isVideo ? Wallpapers.playOf(root.path) : ""
        play: root.visible && root.playing && !ShellState.locked
    }
}
