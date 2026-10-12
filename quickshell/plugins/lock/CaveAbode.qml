pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.config

// The lock's look and its settings. In the shell the lock takes the shell's
// own palette (or the original ink and gold: the Session & lock page), and
// the shell locks before every sleep: it holds a logind delay inhibitor and,
// on PrepareForSleep, locks, gives the lock a moment to cover the screens,
// then lets the sleep go ahead (cave-abode's sleep watcher, as shell code).
//
// The greeter still reads what the Noctalia plugin (nafeel/cave-abode)
// writes into its data dir (CAVE_ABODE_STATE):
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

    // The wallpaper behind the lock: the shell's own (it used to be the
    // cave-abode plugin's copy of Noctalia's, which stopped following once
    // the shell took the wallpaper over). A live one plays on the lock.
    readonly property string wallpaperPath: greeter ? stateDir + "/wallpaper" : (Wallpapers.current || settings.wallpaper || "")
    readonly property string wallpaper: wallpaperPath ? "file://" + wallpaperPath : ""
    readonly property string avatar: greeter ? "file://" + stateDir + "/avatar"
        : "file://" + Quickshell.env("HOME") + "/.face"
    readonly property string stats: stateDir + "/lockstats.json"

    // Greeter only: who logs in, and the session greetd starts for them.
    readonly property string user: Quickshell.env("CAVE_ABODE_USER") || Quickshell.env("USER") || "player"
    readonly property string session: settings.greeter_session || "start-umbriel"

    // The lock's part of the Settings panel's Session & lock page.
    readonly property SettingsPage options: SettingsPage {
        name: "session"
        order: 39

        SettingItem {
            key: "lock.beforeSleep"
            kind: "toggle"
            icon: "lock_clock"
            section: "Lock"
            label: "Lock before sleep"
            description: "Lid closed, power key, idle or a sleep from anywhere: the screen is locked first."
            def: true
        }
        SettingItem {
            key: "lock.palette"
            label: "Lock colours"
            def: "theme"
            options: [
                {
                    value: "theme",
                    icon: "palette",
                    label: "The theme's"
                },
                {
                    value: "original",
                    icon: "brush",
                    label: "Ink and gold"
                }
            ]
        }
    }

    // Until these load, or if they're missing, the theme keeps its original
    // ink-and-gold palette.
    property var settings: ({})
    // The greeter's palette (the plugin's colors.json); in the shell, the
    // shell's own.
    property var greeterPalette: ({})
    readonly property var palette: greeter ? greeterPalette : shellPalette
    readonly property bool followPalette: greeter ? settings.palette !== "original" : options.v["lock.palette"] === "theme"

    // The shell's palette on the lock's roles (as the plugin mapped
    // Noctalia's). A light theme keeps the original ink and gold: the lock
    // always sits on a dark ink backdrop.
    readonly property var shellPalette: {
        if (Colours.light)
            return {};
        const p = Colours.palette;
        const hex = c => c.toString().slice(0, 7);
        const mix = (a, b, t) => Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
        return {
            ink: hex(p.m3surface),
            night: hex(p.m3surfaceContainerHigh),
            mist: hex(p.m3onSurfaceVariant),
            paper: hex(p.m3onSurface),
            gold: hex(p.m3primary),
            paperDim: hex(mix(p.m3onSurfaceVariant, p.m3surface, 0.18)),
            goldHi: hex(mix(p.m3primary, Qt.rgba(1, 1, 1, 1), 0.35)),
            jade: hex(p.m3tertiary),
            cinnabar: hex(p.m3error),
            ember: hex(p.m3secondary)
        };
    }

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
    readonly property bool captureAvailable: !greeter && Plugins.instance("capture") !== null
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
        Plugins.instance("capture")?.capture?.request(event, "");
    }

    // The shell's Capture service runs the capture now.
    Binding {
        target: root
        property: "capture"
        value: Plugins.instance("capture")?.capture?.state ?? ({})
        when: root.captureAvailable
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
        onLoaded: root.greeterPalette = root._parse(text())
    }

    // ── Lock before sleep ──
    readonly property bool sleepWatch: !greeter && options.v["lock.beforeSleep"] === true
    // The delay inhibitor is held until a sleep starts.
    property bool holding: true

    Process {
        running: root.sleepWatch && root.holding
        // Both die with the shell (pdeathsig), so a restart leaves no
        // inhibitor behind: the lock is held by the sleep's file descriptor.
        command: ["setpriv", "--pdeathsig", "TERM", "systemd-inhibit", "--what=sleep", "--mode=delay", "--who=nafeel shell", "--why=Lock the screen before sleep", "setpriv", "--pdeathsig", "KILL", "sleep", "infinity"]
    }

    Process {
        running: root.sleepWatch
        command: ["setpriv", "--pdeathsig", "TERM", "gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1", "--object-path", "/org/freedesktop/login1"]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes("PrepareForSleep (true,)")) {
                    console.log("lock: sleeping, locking first");
                    Session.run("lock");
                    release.restart();
                } else if (line.includes("PrepareForSleep (false,)")) {
                    root.holding = true;
                }
            }
        }
    }

    // A moment for the lock to cover the screens, then the sleep goes on.
    Timer {
        id: release

        interval: 1000
        onTriggered: root.holding = false
    }
}
