pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// One of a screen's two wallpaper slots: a picture, or a live wallpaper (a
// video, looped, silent). `ready` once there's something to show (decoded, or
// the video's first frames), `failed` if it can't be; settled() either way. A
// video plays only while `playing`; held, it keeps its current frame. It
// plays the file, or its 1080p / 720p copy (the live resolution setting).
Item {
    id: root

    property string path: ""
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

    // A live wallpaper's still frame under the player: shown while it
    // starts (no black flash) and while the player is let go.
    Image {
        anchors.fill: parent
        visible: root.isVideo
        source: root.isVideo ? "file://" + Wallpapers.stillOf(root.path) : ""
        sourceSize: root.decode
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
    }

    // A live wallpaper (one player at a time: two decoders at once stalled,
    // so it's let go while the lock screen plays it).
    Loader {
        anchors.fill: parent
        active: root.path !== "" && Wallpapers.isVideo(root.path) && !ShellState.locked
        sourceComponent: VideoLayer {
            source: "file://" + Wallpapers.playOf(root.path)
            run: root.playing
            onFirstFrame: root._done(true)
            onBroken: root._done(false)
        }
    }
}
