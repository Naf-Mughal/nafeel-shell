import QtQuick
import Nafeel

// A live wallpaper's player: the video looped and silent, `run` to play or
// hold (held, it keeps its frame). firstFrame() once there's a picture.
// libmpv in the scene (Nafeel's MpvVideo): decoded on the GPU (VAAPI) and drawn
// straight into the item, scaled to it, the frame never through the CPU. (Qt
// Multimedia's player cost ~20% of the GPU for a 4K video, its frames copied
// and converted; a play() asked before the file loaded was dropped.)
Item {
    id: layer

    property string source
    property bool run: true
    property int startAt: 0
    readonly property int position: video.position
    property bool started: false

    signal firstFrame
    signal broken

    MpvVideo {
        id: video

        anchors.fill: parent
        source: layer.source
        playing: layer.run
        startAt: layer.startAt
        onFirstFrame: {
            if (layer.started)
                return;
            layer.started = true;
            layer.firstFrame();
        }
        onBroken: layer.broken()
    }
}
