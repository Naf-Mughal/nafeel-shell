import QtQuick
import Nafeel

// A live wallpaper's player: the video looped and silent, `run` to play or
// hold (held, it keeps its frame). firstFrame() once there's a picture.
//
// `direct` (the desktop): Nafeel's DmabufVideo, the frames decoded and
// scaled on the GPU and handed to the compositor as they are, on a
// subsurface under the window: nothing drawn in the shell. Once `under`
// (its first frame up) the window must be clear over it. If it can't run
// (no VAAPI, no dmabuf), the scene player instead, by itself.
// Otherwise (the lock screen, which draws over and around its video): libmpv
// in the scene (Nafeel's MpvVideo), decoded on the GPU (VAAPI) and drawn
// into the item. (Qt Multimedia's player cost ~20% of the GPU for a 4K
// video, its frames copied and converted; a play() asked before the file
// loaded was dropped.)
Item {
    id: vl

    property string source
    property bool run: true
    property int startAt: 0
    property bool direct: false
    // At most this many frames a second (0: the file's own; direct only).
    property int maxFps: 0
    readonly property bool under: vl.direct && !vl.fellBack && (player.item?.ready ?? false)
    readonly property int position: player.item?.position ?? 0
    property bool started: false
    property bool fellBack: false

    signal firstFrame
    signal broken

    function _first(): void {
        if (vl.started)
            return;
        vl.started = true;
        vl.firstFrame();
    }

    Loader {
        id: player

        anchors.fill: parent
        sourceComponent: vl.direct && !vl.fellBack ? directPlayer : scenePlayer
    }

    Component {
        id: directPlayer

        DmabufVideo {
            source: vl.source
            playing: vl.run
            startAt: vl.startAt
            maxFps: vl.maxFps
            onFirstFrame: vl._first()
            onBroken: {
                console.warn("live wallpaper: the direct engine can't run here; drawing it in the scene");
                vl.fellBack = true;
            }
        }
    }

    Component {
        id: scenePlayer

        MpvVideo {
            source: vl.source
            playing: vl.run
            startAt: vl.startAt
            onFirstFrame: vl._first()
            onBroken: vl.broken()
        }
    }
}
