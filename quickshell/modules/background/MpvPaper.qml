import QtQuick
import Quickshell
import Quickshell.Io

// A live wallpaper played outside the shell (ROADMAP O6): mpvpaper, mpv with
// hardware decoding, on the layer just above the shell's own wallpaper (so
// the still frame the shell draws under it shows whenever it's stopped: while
// a change soaks in, locked, under a fullscreen window, on battery). Decoding
// a 4K video in the shell cost it ~250 MB; here it's mpv's, mostly on the GPU.
Process {
    id: root

    // The screen's output name and the video; it runs while `play`.
    required property string output
    required property string path
    property bool play: true

    running: play && path !== "" && output !== ""
    command: ["mpvpaper", "--layer", "bottom", "--mpv-options", "no-audio loop hwdec=auto-safe panscan=1.0 keep-open=yes", output, path]
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
