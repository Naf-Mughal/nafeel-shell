import QtQuick
import Quickshell
import Quickshell.Io

// A live wallpaper played outside the shell (ROADMAP O6): mpvpaper, mpv with
// hardware decoding, on the layer just above the shell's own wallpaper (so
// the still frame the shell draws under it shows whenever it's stopped: while
// a change soaks in, locked, under a fullscreen window, on battery). Decoding
// a 4K video in the shell cost it ~250 MB; here it's mpv's, mostly on the GPU.
//
// It's started only with a file to play, and started afresh when the file
// changes (a Process doesn't restart when its command does: started before
// the slot knew its video, it played nothing, a black layer over the still).
Process {
    id: root

    // The screen's output name and the video; it runs while `play`.
    required property string output
    required property string path
    property bool play: true

    // What should be playing now ("" for nothing), and what is.
    readonly property string want: play && output !== "" ? path : ""
    property string playing: ""
    // Starts that died within two seconds in a row (a file mpv can't play):
    // after three, it stops trying until the file changes.
    property int quickDeaths: 0
    property real startedAt: 0

    function apply(): void {
        if (want === playing && running)
            return;
        if (running) {
            running = false; // onRunningChanged starts the new one
            return;
        }
        start();
    }

    function start(): void {
        if (!want || quickDeaths >= 3)
            return;
        playing = want;
        command = ["mpvpaper", "--layer", "bottom", "--mpv-options", "no-audio loop hwdec=auto-safe panscan=1.0 keep-open=yes", output, want];
        startedAt = Date.now();
        running = true;
    }

    onWantChanged: {
        quickDeaths = 0;
        Qt.callLater(apply);
    }
    onRunningChanged: {
        if (running)
            return;
        if (playing === want && Date.now() - startedAt < 2000)
            quickDeaths++;
        playing = "";
        Qt.callLater(start);
    }
    Component.onCompleted: Qt.callLater(apply)

    stdout: SplitParser {
        onRead: line => {}
    }
    stderr: SplitParser {
        onRead: line => {
            if (/error|fail/i.test(line))
                console.warn(`mpvpaper ${root.output}: ${line}`);
        }
    }
}
