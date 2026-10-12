pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The bridge to the Noctalia plugin (nafeel/cave-abode). Its service writes,
// into the plugin data dir (CAVE_ABODE_STATE):
//   settings.json  { palette, wallpaper, greeter_session, ... }
//   colors.json    Noctalia's palette mapped onto the theme's roles
// and the lock writes lockstats.json there itself. The greeter runs as the
// `greeter` user and reads the copies the service mirrors into
// /var/lib/cave-abode (greeter-setup.sh creates it).
Singleton {
    id: root

    readonly property bool greeter: Quickshell.env("CAVE_ABODE_GREETER") === "1"
    readonly property string stateDir: Quickshell.env("CAVE_ABODE_STATE")
        || (greeter ? "/var/lib/cave-abode"
                    : Quickshell.env("HOME") + "/.local/state/noctalia/plugins/data/nafeel/cave-abode")

    readonly property string wallpaper: greeter ? "file://" + stateDir + "/wallpaper"
        : settings.wallpaper ? "file://" + settings.wallpaper : ""
    readonly property string avatar: greeter ? "file://" + stateDir + "/avatar"
        : "file://" + Quickshell.env("HOME") + "/.face"
    readonly property string stats: stateDir + "/lockstats.json"

    // Greeter only: who logs in, and the session greetd starts for them.
    readonly property string user: Quickshell.env("CAVE_ABODE_USER") || Quickshell.env("USER") || "player"
    readonly property string session: settings.greeter_session || "start-umbriel"

    // Until these load, or if they're missing, the theme keeps its original
    // ink-and-gold palette.
    property var settings: ({})
    property var palette: ({})
    readonly property bool followPalette: settings.palette !== "original"

    // A palette role for Xian.qml: Noctalia's colour, or `fallback`.
    function color(role, fallback) {
        const c = followPalette ? palette[role] : undefined;
        return typeof c === "string" && /^#[0-9a-fA-F]{6,8}$/.test(c) ? c : fallback;
    }

    // Choreography lengths for LockContext.configure(), from the reference
    // shell's theme registry entry for "xianxia".
    readonly property var timing: ({
        introMs: 1700,
        outroMs: 1150,
        rewardBaseMs: 1400,
        rewardLevelUpMs: 1000,
        rewardAchievementMs: 450,
        ambient: true
    })

    // ── Capture (plugin nafeel/capture) ─────────────────────────────
    // The lock's record and screenshot tokens drive the Capture plugin over
    // Noctalia IPC and mirror its recording state from the file it writes.
    readonly property bool captureAvailable: !greeter
    property var capture: ({})
    readonly property bool recording: capture.recording === true
    readonly property bool recordingPaused: capture.paused === true

    // Seconds recorded at `now` (a Date), not counting pauses.
    function recordedSeconds(now) {
        if (!recording || !capture.startedAt)
            return 0;
        const t = now.getTime();
        const paused = (capture.pausedMs || 0) + (recordingPaused ? t - (capture.pausedAt || t) : 0);
        return Math.max(0, Math.floor((t - capture.startedAt - paused) / 1000));
    }

    function captureCommand(event) {
        Quickshell.execDetached(["noctalia", "msg", "plugin", "nafeel/capture:service", "all", event]);
    }

    FileView {
        path: root.captureAvailable ? Quickshell.env("HOME") + "/.local/state/noctalia/plugins/data/nafeel/capture/state.json" : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.capture = root._parse(text())
    }

    function _parse(text) {
        try {
            const v = JSON.parse(text);
            return v && typeof v === "object" ? v : {};
        } catch (e) {
            return {};
        }
    }

    FileView {
        path: root.stateDir + "/settings.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.settings = root._parse(text())
    }

    FileView {
        path: root.stateDir + "/colors.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.palette = root._parse(text())
    }
}
