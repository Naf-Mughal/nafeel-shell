// Idle management, run by the shell: a port of Noctalia's idle manager
// (src/idle/idle_manager.cpp, MIT) onto Quickshell's IdleMonitor (the same
// ext-idle-notify protocol Noctalia drives by hand).
//
// Four stages, dim, lock, screen off and suspend, with their own timeouts
// plugged in and on battery (the Settings panel's Power & idle page; 0 turns
// a stage off), and the set follows the charger. Each stage fires after its
// timeout of no input unless something inhibits idle (caffeine, a video
// playing: Wayland idle inhibitors; an app over D-Bus: ScreenSaver, the
// native org.freedesktop.ScreenSaver service); input undoes it. As Noctalia
// does, a pre-action fade warns first (the screens darken over `fade`
// seconds; move and it's cancelled), and every stage that comes due during
// a fade joins it.
//
// Dim lowers the backlight to the dim level (never up) and puts it back on
// return. Suspend waits while audio plays (music on the lock screen keeps
// going) until it has been quiet a while, then locks and sleeps.
// (Before the settings, idle-kit's profiles/{ac,battery}.toml held these.)
//
// Bus: "idle.idled" / "idle.resumed" { name, action }, "idle.grace"
// { active, willLock }, retained "idle.state" { dimmed, screenOff }. The lock
// screen keeps its motion (and a live wallpaper) running until `dimmed`.
//
// IPC: qs -p <shell> ipc call idle status

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Nafeel
import qs.config
import qs.services

Scope {
    id: root

    // The Settings panel's Power & idle page (Power adds the battery's part).
    readonly property SettingsPage settings: SettingsPage {
        name: "power"
        title: "Power & idle"
        gloss: "电源"
        icon: "battery_charging_full"
        order: 35
        description: "What happens when you step away, plugged in and on battery."

        SettingItem {
            key: "idle.ac.dim"
            kind: "number"
            section: "Plugged in"
            label: "Dim the screen"
            def: 570
            min: 0
            max: 7200
            step: 15
            format: "duration"
            zeroLabel: "Never"
        }
        SettingItem {
            key: "idle.ac.lock"
            kind: "number"
            label: "Lock"
            def: 600
            min: 0
            max: 7200
            step: 15
            format: "duration"
            zeroLabel: "Never"
        }
        SettingItem {
            key: "idle.ac.screenOff"
            kind: "number"
            label: "Turn the screen off"
            def: 630
            min: 0
            max: 7200
            step: 15
            format: "duration"
            zeroLabel: "Never"
        }
        SettingItem {
            key: "idle.ac.suspend"
            kind: "number"
            label: "Sleep"
            def: 1800
            min: 0
            max: 7200
            step: 15
            format: "duration"
            zeroLabel: "Never"
        }
        SettingItem {
            key: "idle.battery.dim"
            kind: "number"
            section: "On battery"
            label: "Dim the screen"
            def: 150
            min: 0
            max: 7200
            step: 15
            format: "duration"
            zeroLabel: "Never"
        }
        SettingItem {
            key: "idle.battery.lock"
            kind: "number"
            label: "Lock"
            def: 180
            min: 0
            max: 7200
            step: 15
            format: "duration"
            zeroLabel: "Never"
        }
        SettingItem {
            key: "idle.battery.screenOff"
            kind: "number"
            label: "Turn the screen off"
            def: 195
            min: 0
            max: 7200
            step: 15
            format: "duration"
            zeroLabel: "Never"
        }
        SettingItem {
            key: "idle.battery.suspend"
            kind: "number"
            label: "Sleep"
            def: 600
            min: 0
            max: 7200
            step: 15
            format: "duration"
            zeroLabel: "Never"
        }
        SettingItem {
            key: "idle.fade"
            kind: "number"
            section: "Behaviour"
            label: "Warning fade"
            description: "The screen darkens this long before a stage; move to cancel it."
            def: 3
            min: 0
            max: 10
            step: 0.5
            unit: " s"
            zeroLabel: "Off"
        }
        SettingItem {
            key: "idle.dimLevel"
            kind: "number"
            label: "Dim to"
            description: "The backlight while dimmed (never raised if it's already lower)."
            def: 30
            min: 5
            max: 80
            step: 5
            unit: "%"
        }
        SettingItem {
            key: "idle.waitForAudio"
            kind: "toggle"
            icon: "music_note"
            label: "Don't sleep while audio plays"
            description: "Music and podcasts keep going on the lock screen; sleep comes once it's quiet."
            def: true
        }
        SettingItem {
            key: "idle.quiet"
            kind: "number"
            label: "Quiet before sleep"
            description: "How long audio must have stopped first."
            def: 120
            min: 0
            max: 600
            step: 30
            format: "duration"
            zeroLabel: "At once"
            shown: root.settings.v["idle.waitForAudio"] === true
        }
    }

    readonly property string profile: !Power.hasBattery || Power.charging ? "ac" : "battery"
    readonly property var config: {
        const v = settings.v;
        const stage = (name, key, action) => ({
                    name,
                    action,
                    timeout: v[`idle.${profile}.${key}`],
                    enabled: v[`idle.${profile}.${key}`] > 0
                });
        return {
            fade: v["idle.fade"],
            behaviors: [stage("dim", "dim", "dim"), stage("lock", "lock", "lock"), stage("screen-off", "screenOff", "screen_off"), stage("suspend", "suspend", "suspend_quiet")]
        };
    }
    readonly property real fade: config.fade ?? 0

    // name -> "waiting" | "fading" | "idled"
    property var phases: ({})
    // The pre-action fade: running, its length, who waits on it, whether it
    // ends in a lock.
    property bool fading: false
    property var graceNames: []
    property bool graceWillLock: false

    // The screen has been dimmed or turned off by a behaviour (the lock goes
    // still then).
    readonly property bool dimmed: (config.behaviors ?? []).some(b => phases[b.name] === "idled" && (b.name === "dim" || b.action === "screen_off"))
    readonly property bool screenOff: (config.behaviors ?? []).some(b => phases[b.name] === "idled" && b.action === "screen_off")
    // Does this profile have a stage that dims at all.
    readonly property bool hasDimStage: (config.behaviors ?? []).some(b => b.enabled && (b.name === "dim" || b.action === "screen_off"))

    onDimmedChanged: Bus.retain("idle.state", {
        dimmed,
        screenOff
    })

    function _set(name: string, phase: string): void {
        const p = Object.assign({}, phases);
        p[name] = phase;
        phases = p;
    }

    function _willLock(b: var): bool {
        return b.action === "lock" || b.action === "lock_and_suspend";
    }

    // ── From the monitors ──

    function _idled(b: var): void {
        if ((phases[b.name] ?? "waiting") !== "waiting")
            return;
        if (fade > 0.0005) {
            _set(b.name, "fading");
            graceNames = [...graceNames, b.name];
            graceWillLock = graceWillLock || _willLock(b);
            if (!fading) {
                fading = true;
                console.log(`idle: '${b.name}' pre-action fade ${fade}s`);
                Bus.publish("idle.grace", {
                    active: true,
                    willLock: graceWillLock
                });
                graceTimer.interval = Math.round(fade * 1000);
                graceTimer.restart();
            } else {
                console.log(`idle: '${b.name}' joined the fade`);
            }
            return;
        }
        _set(b.name, "idled");
        console.log(`idle: '${b.name}' triggered`);
        _run(b);
    }

    function _resumed(b: var): void {
        const phase = phases[b.name] ?? "waiting";
        if (phase === "fading") {
            console.log(`idle: '${b.name}' fade cancelled (you're back)`);
            _cancelGrace();
            return;
        }
        if (phase !== "idled")
            return;
        _set(b.name, "waiting");
        console.log(`idle: '${b.name}' resumed`);
        _resume(b);
    }

    function _cancelGrace(): void {
        if (!fading)
            return;
        for (const n of graceNames)
            _set(n, "waiting");
        graceNames = [];
        graceWillLock = false;
        fading = false;
        graceTimer.stop();
        Bus.publish("idle.grace", {
            active: false,
            willLock: false
        });
    }

    // The fade is done: tear the overlay down first (suspend can freeze the
    // process before a later hide; the lock's capture must see the desktop),
    // then the actions.
    function _graceDone(): void {
        if (!fading)
            return;
        const names = graceNames;
        graceNames = [];
        graceWillLock = false;
        fading = false;
        Bus.publish("idle.grace", {
            active: false,
            willLock: false
        });
        const due = (config.behaviors ?? []).filter(b => names.includes(b.name) && phases[b.name] === "fading");
        for (const b of due)
            _set(b.name, "idled");
        afterGrace.due = due;
        afterGrace.restart();
    }

    Timer {
        id: graceTimer

        onTriggered: root._graceDone()
    }

    // A couple of frames for the overlay to go before the actions.
    Timer {
        id: afterGrace

        property var due: []

        interval: 120
        onTriggered: {
            for (const b of due) {
                console.log(`idle: '${b.name}' triggered after the fade`);
                root._run(b);
            }
            due = [];
        }
    }

    // ── Actions ──

    function _run(b: var): void {
        Bus.publish("idle.idled", {
            name: b.name,
            action: b.action
        });
        switch (b.action) {
        case "dim":
            _dim();
            break;
        case "suspend_quiet":
            if (settings.v["idle.waitForAudio"])
                quiet.begin();
            else
                Session.run("suspend");
            break;
        case "lock":
            Session.run("lock");
            break;
        case "screen_off":
            Umbriel.dispatch("dpms-off");
            break;
        case "suspend":
            Quickshell.execDetached(["systemctl", "suspend"]);
            break;
        case "lock_and_suspend":
            Session.run("suspend");
            break;
        default:
            if (b.command)
                Quickshell.execDetached(["sh", "-c", b.command]);
        }
    }

    function _resume(b: var): void {
        Bus.publish("idle.resumed", {
            name: b.name,
            action: b.action
        });
        if (b.action === "screen_off")
            Umbriel.dispatch("dpms-on");
        if (b.action === "dim")
            _undim();
        if (b.action === "suspend_quiet")
            quiet.cancel();
        if (b.resumeCommand)
            Quickshell.execDetached(["sh", "-c", b.resumeCommand]);
    }

    // ── The monitors: one per behaviour of the current profile ──

    Instantiator {
        model: root.config.behaviors ?? []

        delegate: IdleMonitor {
            required property var modelData
            // While locked, a behaviour with a locked timeout re-arms at it.
            readonly property real seconds: ShellState.locked && modelData.lockedTimeout > 0 ? modelData.lockedTimeout : modelData.timeout

            // Also held off while an app keeps the screen awake over D-Bus
            // (org.freedesktop.ScreenSaver: players, games, Electron apps).
            enabled: modelData.enabled && seconds > 0 && !ScreenSaver.inhibited
            timeout: seconds
            respectInhibitors: true
            onIsIdleChanged: {
                if (isIdle)
                    root._idled(modelData);
                else
                    root._resumed(modelData);
            }
        }
    }

    // A profile switch (the charger) re-arms everything: anything idled is
    // resumed first so nothing stays dimmed or off.
    onProfileChanged: {
        _cancelGrace();
        for (const b of (config?.behaviors ?? []))
            if (phases[b.name] === "idled")
                _resume(b);
        phases = {};
    }

    // ── Dim ──
    // The backlight before dimming (-1: not dimmed by us).
    property real undimmed: -1

    function _dim(): void {
        const to = settings.v["idle.dimLevel"] / 100;
        if (!Brightness.available || Brightness.level <= to)
            return;
        undimmed = Brightness.level;
        Brightness.quietly(to);
    }

    function _undim(): void {
        if (undimmed < 0)
            return;
        Brightness.quietly(undimmed);
        undimmed = -1;
    }

    // ── Sleep once it's quiet ──
    // Polls for playing audio (an uncorked stream, else an MPRIS player
    // playing) every 10 s; quiet for long enough: lock and sleep.
    QtObject {
        id: quiet

        property bool waiting: false
        // Nothing heard yet: silence on the first check means sleep on time.
        property bool first: true
        property int quietFor: 0

        function begin(): void {
            waiting = true;
            first = true;
            quietFor = 0;
            poll.restart();
            probe.running = true;
        }

        function cancel(): void {
            waiting = false;
            poll.stop();
        }

        function heard(playing: bool): void {
            if (!waiting)
                return;
            const due = root.settings.v["idle.quiet"];
            if (playing)
                quietFor = 0;
            else
                quietFor = first ? due : quietFor + poll.interval / 1000;
            first = false;
            if (quietFor >= due) {
                cancel();
                console.log("idle: quiet, sleeping");
                Session.run("suspend");
            }
        }
    }

    Timer {
        id: poll

        interval: 10000
        repeat: true
        onTriggered: probe.running = true
    }

    Process {
        id: probe

        command: ["sh", "-c", "pactl list sink-inputs 2>/dev/null | grep -q 'Corked: no' || playerctl -a status 2>/dev/null | grep -qx Playing"]
        onExited: code => quiet.heard(code === 0)
    }

    IpcHandler {
        target: "idle"

        function status(): string {
            return JSON.stringify({
                dbusInhibitors: ScreenSaver.inhibitors,
                screenSaverOwned: ScreenSaver.owned,
                profile: root.profile,
                fading: root.fading,
                dimmed: root.dimmed,
                phases: root.phases,
                behaviors: (root.config.behaviors ?? []).map(b => `${b.name}:${b.enabled ? b.timeout + "s" : "off"}:${b.action}`)
            });
        }
    }
}
