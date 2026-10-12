// Screenshots and screen recordings, run by the shell (ported from the
// nafeel/capture Noctalia plugin's service): the region picker is the shell's
// own (Picker.qml: frozen screens, drag a region, a click
// takes the screen), screenshots are cut out of the frozen still, saved to
// ~/Pictures/Screenshots and copied as an image; recordings are
// gpu-screen-recorder through bin/record.sh (stop SIGINT, pause SIGUSR2, the
// mic muted live with pactl). "edit" picks a region and opens it in the
// shell's annotator (Annotator.qml). Each one posts a notification with a preview
// and Open / Edit / Folder / Delete (bin/capture-notify). While the screen is
// locked umbriel refuses screencopy, so both take the whole monitor with
// gpu-screen-recorder instead.
//
// The dialog's choices persist in ~/.local/state/nafeel-shell/capture/
// prefs.json; the state is written to state.json beside it (shell-msg reads
// it). Requests (IPC target "capture", the dialog, the bar, the lock):
//   screenshot [region|screen|edit] · snip · capture · record [region|screen]
//   start [region|screen] · stop · pause · mic · toolbar · set <key> <value>

import QtQuick
import Quickshell
import Quickshell.Io
import Nafeel
import qs.config
import qs.services

Scope {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string dir: `${Quickshell.env("XDG_STATE_HOME") || home + "/.local/state"}/nafeel-shell/capture`
    readonly property string bin: Quickshell.shellDir + "/../bin"
    // The Settings panel's Capture page.
    readonly property SettingsPage settings: SettingsPage {
        name: "capture"
        title: "Capture"
        gloss: "摄影"
        icon: "photo_camera"
        order: 45
        description: "Where screenshots and recordings go, and how recordings are made."

        SettingItem {
            key: "capture.shotDir"
            kind: "text"
            section: "Screenshots"
            label: "Folder"
            placeholder: "~/Pictures/Screenshots"
            def: "~/Pictures/Screenshots"
        }
        SettingItem {
            key: "capture.copy"
            kind: "toggle"
            icon: "content_copy"
            label: "Copy to the clipboard"
            description: "Each screenshot is copied as an image as well as saved."
            def: true
        }
        SettingItem {
            key: "capture.recordDir"
            kind: "text"
            section: "Recordings"
            label: "Folder"
            placeholder: "~/Videos/Recordings"
            def: "~/Videos/Recordings"
        }
        SettingItem {
            key: "capture.fps"
            label: "Frame rate"
            def: 60
            options: [
                {
                    value: 30,
                    icon: "slow_motion_video",
                    label: "30 fps"
                },
                {
                    value: 60,
                    icon: "videocam",
                    label: "60 fps"
                },
                {
                    value: 120,
                    icon: "speed",
                    label: "120 fps"
                }
            ]
        }
        SettingItem {
            key: "capture.quality"
            label: "Quality"
            description: "Higher is sharper and larger."
            def: "very_high"
            options: [
                {
                    value: "medium",
                    icon: "sd",
                    label: "Medium"
                },
                {
                    value: "high",
                    icon: "hd",
                    label: "High"
                },
                {
                    value: "very_high",
                    icon: "high_quality",
                    label: "Very high"
                },
                {
                    value: "ultra",
                    icon: "4k",
                    label: "Ultra"
                }
            ]
        }
        SettingItem {
            key: "capture.cursor"
            kind: "toggle"
            icon: "arrow_selector_tool"
            label: "Record the cursor"
            def: true
        }
    }

    function expand(path: string): string {
        return path.startsWith("~") ? home + path.slice(1) : path;
    }

    readonly property string shotDir: expand(settings.v["capture.shotDir"].trim() || "~/Pictures/Screenshots")
    readonly property string recordDir: expand(settings.v["capture.recordDir"].trim() || "~/Videos/Recordings")

    // { recording, starting, paused, startedAt, pausedAt, pausedMs, mode, file, micMuted }
    property var state: ({
            recording: false,
            starting: false,
            paused: false,
            startedAt: 0,
            pausedAt: 0,
            pausedMs: 0,
            mode: "",
            file: "",
            micMuted: false
        })
    // The capture dialog's choices: { kind: screenshot|record, shot:
    // region|screen|edit, area: region|screen, delay: 0|3|5|10, mic, system }.
    property var prefs: ({
            kind: "screenshot",
            shot: "region",
            area: "region",
            delay: 0,
            mic: false,
            system: true
        })
    readonly property bool recording: !!state.recording
    readonly property bool paused: !!state.paused
    // The region picker (Picker.qml sets itself here).
    property var picker: null
    // The annotator (Annotator.qml sets itself here).
    property var annotator: null
    property string recorderPid: ""

    // Seconds recorded, not counting pauses.
    function elapsed(nowMs: real): real {
        if (!recording || !state.startedAt)
            return 0;
        const p = (state.pausedMs ?? 0) + (state.paused ? nowMs - (state.pausedAt ?? nowMs) : 0);
        return Math.max(0, (nowMs - state.startedAt - p) / 1000);
    }

    function setState(changes: var): void {
        state = Object.assign({}, state, changes);
        stateFile.setText(JSON.stringify(state));
    }

    function setPref(key: string, value: var): void {
        if (key === "mic" || key === "system") {
            if (recording)
                return;
            value = value === true || value === "true";
        }
        if (key === "delay")
            value = Number(value);
        const next = Object.assign({}, prefs);
        next[key] = value;
        prefs = next;
        prefsFile.setText(JSON.stringify(prefs, null, 2));
    }

    // An action, as the plugin's IPC took them: "screenshot region", "stop",
    // "set kind record", …
    function request(action: string, arg: string): void {
        arg = (arg ?? "").trim();
        switch (action) {
        case "screenshot":
            shot(arg || "region", 0);
            break;
        case "annotate":
            // An image file, or none: pick a region first.
            if (arg)
                annotate(arg, false);
            else
                shot("edit", 0);
            break;
        case "snip":
            setPref("kind", "screenshot");
            setPref("shot", "region");
            shot("region", 0);
            break;
        case "capture":
            go(0);
            break;
        case "record":
            if (recording)
                stop();
            else if (!state.starting)
                startRecording(arg || prefs.area, 0);
            break;
        case "start":
            startRecording(arg || prefs.area, 0);
            break;
        case "stop":
            stop();
            break;
        case "pause":
            togglePause();
            break;
        case "mic":
            toggleMic();
            break;
        case "toolbar":
            ShellState.anchorTo("bar:capture");
            ShellState.pin("bar:capture", Umbriel.focusedOutput);
            break;
        case "set":
            {
                const parts = arg.split(/\s+/);
                setPref(parts[0], parts[1]);
                break;
            }
        }
    }

    // The dialog's big button: screenshot or record with its choices, after
    // `afterMs` (time for the dialog to close, unless it stays in the shot).
    function go(afterMs: int): void {
        goTimer.interval = Math.max(1, afterMs);
        goTimer.restart();
    }

    // ── Screenshots ─────────────────────────────────────────────────────
    function newShotPath(): string {
        return `${shotDir}/screenshot_${Qt.formatDateTime(new Date(), "yyyyMMdd_HHmmss")}.png`;
    }

    function shot(mode: string, delayMs: int): void {
        if (ShellState.locked) {
            lockedShot();
            return;
        }
        Quickshell.execDetached(["mkdir", "-p", shotDir]);
        shotTimer.mode = mode;
        shotTimer.interval = Math.max(1, delayMs);
        shotTimer.restart();
    }

    // Open `path` in the annotator; `temporary`: a still to remove after.
    function annotate(path: string, temporary: bool): void {
        if (annotator)
            annotator.open(path, temporary);
    }

    // Where the picker leaves a region to annotate.
    function newAnnotatePath(): string {
        return `${dir}/annotate-${Date.now()}.png`;
    }

    // From the picker: a screenshot saved at `path`.
    function shotTaken(path: string): void {
        const copy = settings.v["capture.copy"];
        if (copy)
            Clipboard.copyImageFile(path);
        Quickshell.execDetached([bin + "/capture-notify", "shot", path, copy ? "copied" : ""]);
    }

    function pickCancelled(purpose: string): void {
        if (purpose === "record")
            setState({
                starting: false
            });
    }

    // Locked: the focused monitor, read from the GPU by gpu-screen-recorder.
    function lockedShot(): void {
        const path = newShotPath();
        lockedShotProc.path = path;
        lockedShotProc.command = ["sh", "-c", 'mkdir -p "$1" && exec gpu-screen-recorder -w "$2" -cursor no -o "$3"', "sh", shotDir, Umbriel.focusedOutput || "screen", path];
        lockedShotProc.running = true;
    }

    // ── Recording ───────────────────────────────────────────────────────
    function startRecording(mode: string, delayMs: int): void {
        if (recording || state.starting)
            return;
        setState({
            starting: true
        });
        recordTimer.mode = mode === "screen" || ShellState.locked ? "screen" : "region";
        recordTimer.interval = Math.max(1, delayMs);
        recordTimer.restart();
    }

    // From the picker: the region to record, in screen coordinates.
    function recordRegion(output: string, area: rect): void {
        // Encoders want even dimensions.
        const w = Math.floor(area.width) - Math.floor(area.width) % 2;
        const h = Math.floor(area.height) - Math.floor(area.height) % 2;
        if (w < 2 || h < 2) {
            setState({
                starting: false
            });
            return;
        }
        begin(`${w}x${h}+${Math.round(area.x)}+${Math.round(area.y)}`, "region");
    }

    function begin(target: string, mode: string): void {
        const file = `${recordDir}/recording_${Qt.formatDateTime(new Date(), "yyyyMMdd_HHmmss")}.mp4`;
        const audio = [prefs.system ? "default_output" : "", prefs.mic ? "default_input" : ""].filter(Boolean).join("|");
        const argv = [bin + "/record.sh", "gpu-screen-recorder", "-w", target, "-f", String(settings.v["capture.fps"]), "-q", settings.v["capture.quality"], "-k", "auto", "-cursor", settings.v["capture.cursor"] ? "yes" : "no"];
        if (audio)
            argv.push("-a", audio);
        argv.push("-o", file);
        Quickshell.execDetached(["mkdir", "-p", recordDir]);
        recorder.log = [];
        recorder.file = file;
        setState({
            file: file,
            mode: mode
        });
        recorder.command = argv;
        recorder.running = true;
    }

    function stop(): void {
        if (recorderPid)
            Quickshell.execDetached(["kill", "-INT", recorderPid]);
    }

    function togglePause(): void {
        if (!recorderPid || !recording)
            return;
        Quickshell.execDetached(["kill", "-USR2", recorderPid]);
        const now = Date.now();
        if (state.paused)
            setState({
                paused: false,
                pausedMs: state.pausedMs + now - state.pausedAt,
                pausedAt: 0
            });
        else
            setState({
                paused: true,
                pausedAt: now
            });
    }

    function setMicMuted(muted: bool): void {
        Quickshell.execDetached(["pactl", "set-source-mute", "@DEFAULT_SOURCE@", muted ? "1" : "0"]);
    }

    // During a recording the mic button mutes the microphone itself; it's
    // unmuted again when the recording ends.
    function toggleMic(): void {
        if (recording && prefs.mic) {
            setState({
                micMuted: !state.micMuted
            });
            setMicMuted(state.micMuted);
        } else if (!recording) {
            setPref("mic", !prefs.mic);
        }
    }

    function finished(status: int): void {
        const file = recorder.file;
        if (state.micMuted)
            setMicMuted(false);
        recorderPid = "";
        setState({
            recording: false,
            starting: false,
            paused: false,
            startedAt: 0,
            pausedAt: 0,
            pausedMs: 0,
            mode: "",
            file: "",
            micMuted: false
        });
        notifyRecording.command = ["sh", "-c", 'if [ -s "$1" ]; then exec "$2" record "$1"; else rm -f "$1"; notify-send --app-name=Capture "Recording failed" "$3"; fi', "sh", file, bin + "/capture-notify", recorder.log.join("\n") || `exit ${status}`];
        notifyRecording.running = true;
    }

    Timer {
        id: goTimer

        onTriggered: {
            if (root.prefs.kind === "record")
                root.startRecording(root.prefs.area, 0);
            else
                root.shot(root.prefs.shot, (root.prefs.delay ?? 0) * 1000);
        }
    }

    Timer {
        id: shotTimer

        property string mode: "region"

        onTriggered: root.picker?.begin(mode === "screen" ? "screen" : mode === "edit" ? "annotate" : "shot")
    }

    Timer {
        id: recordTimer

        property string mode: "region"

        onTriggered: {
            if (mode === "screen")
                root.begin(Umbriel.focusedOutput || "screen", "screen");
            else
                root.picker?.begin("record");
        }
    }

    Process {
        id: lockedShotProc

        property string path

        onExited: code => {
            if (code === 0)
                Quickshell.execDetached([root.bin + "/capture-notify", "shot", path]);
            else
                Quickshell.execDetached(["notify-send", "--app-name=Capture", "Screenshot failed", "gpu-screen-recorder couldn't read the screen"]);
        }
    }

    Process {
        id: recorder

        property string file
        property var log: []

        stdout: SplitParser {
            onRead: line => {
                const pid = line.match(/^PID (\d+)$/);
                const exit = line.match(/^EXIT (\d+)$/);
                if (pid) {
                    root.recorderPid = pid[1];
                    root.setState({
                        starting: false,
                        recording: true,
                        startedAt: Date.now()
                    });
                } else if (exit) {
                    root.finished(Number(exit[1]));
                } else if (line.trim()) {
                    recorder.log = [...recorder.log, line.trim()].slice(-8);
                }
            }
        }
    }

    Process {
        id: notifyRecording
    }

    IpcHandler {
        target: "capture"

        function request(action: string, arg: string): void {
            root.request(action, arg);
        }

        function snip(): void {
            root.request("snip", "");
        }

        function record(): void {
            root.request("record", "");
        }

        function state(): string {
            return JSON.stringify(root.state);
        }
    }

    FileView {
        id: prefsFile

        path: root.dir + "/prefs.json"
        printErrors: false
        onLoaded: {
            try {
                root.prefs = Object.assign({}, root.prefs, JSON.parse(text()));
            } catch (e) {}
        }
        // First run: the plugin's choices carry over.
        onLoadFailed: oldPrefs.reload()
    }

    FileView {
        id: oldPrefs

        path: root.home + "/.local/state/noctalia/plugins/data/nafeel/capture/prefs.json"
        printErrors: false
        onLoaded: {
            try {
                root.prefs = Object.assign({}, root.prefs, JSON.parse(text()));
                prefsFile.setText(JSON.stringify(root.prefs, null, 2));
            } catch (e) {}
        }
    }

    FileView {
        id: stateFile

        path: root.dir + "/state.json"
        printErrors: false
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root.dir + "/thumbs"])

    // The initial state, once the folder exists.
    Timer {
        running: true
        interval: 500
        onTriggered: stateFile.setText(JSON.stringify(root.state))
    }
}
