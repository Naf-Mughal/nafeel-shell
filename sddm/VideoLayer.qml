import QtQuick
import QtMultimedia

// A live wallpaper's player: the video looped and silent (no audio output at
// all), `run` to play or hold. firstFrame() once there's a picture.
Item {
    id: layer

    property string source
    property bool run: true
    property int startAt: 0
    readonly property int position: player.position
    property bool started: false

    signal firstFrame
    signal broken

    MediaPlayer {
        id: player

        source: layer.source
        loops: MediaPlayer.Infinite
        videoOutput: out
        Component.onCompleted: play()
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.BufferedMedia || mediaStatus === MediaPlayer.LoadedMedia) {
                if (layer.startAt > 0 && player.seekable)
                    player.position = layer.startAt + 150;
                settle.restart();
            } else if (mediaStatus === MediaPlayer.InvalidMedia) {
                layer.broken();
            }
        }
        onErrorOccurred: layer.broken()
    }

    VideoOutput {
        id: out

        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }

    // A frame or two in, so there's a picture to show.
    Timer {
        id: settle

        interval: 150
        onTriggered: {
            if (layer.started)
                return;
            layer.started = true;
            layer.firstFrame();
            if (!layer.run)
                player.pause();
        }
    }

    onRunChanged: {
        if (run)
            player.play();
        else if (started)
            player.pause();
    }
}
