import QtQuick

// The login screen's side of the cave-abode surface: the same interface as
// the shell's LockContext (phase, passcode buffer, cells, time, lives, idle,
// the power tokens), with SDDM doing the login. Phases: intro -> ready <->
// verifying -> granted -> exiting; SDDM starts the session on success.
Item {
    id: ctx

    required property string userName
    property int sessionIndex: 0
    // 24-hour time (the shell's Time & units setting, exported).
    property bool h24: false

    // ── Lifecycle ──
    property string phase: "intro"
    readonly property bool inputLocked: phase === "verifying" || phase === "granted" || phase === "exiting"
    property double lockedAt: Date.now()
    property int introMs: 1700
    property int outroMs: 1150
    property bool preview: false

    signal denied(bool costLife)
    signal granted
    signal typed(int index)
    signal erased(int index)

    // ── Passcode ──
    property string buffer: ""
    property int cells: 0
    property int combo: 0
    property bool denying: false
    property string message: ""
    property var reward: null

    function setBuffer(text) {
        if (inputLocked || text === buffer)
            return;
        const old = buffer;
        buffer = text;
        poke();
        if (denying) {
            denying = false;
            deniedTimer.stop();
            cells = 0;
        }
        if (text.length > old.length && text.startsWith(old)) {
            for (let i = old.length; i < text.length; i++) {
                combo += 1;
                cells = i + 1;
                typed(i);
            }
        } else if (text.length < old.length && old.startsWith(text)) {
            combo = 0;
            for (let i = old.length - 1; i >= text.length; i--) {
                cells = i;
                erased(i);
            }
        } else {
            combo = text.length;
            cells = text.length;
        }
    }

    function clearInput() {
        if (!inputLocked && buffer.length > 0)
            setBuffer("");
    }

    function submit() {
        if (inputLocked || buffer.length === 0)
            return;
        const response = buffer;
        phase = "verifying";
        buffer = "";
        message = "";
        verifyTimeout.restart();
        if (preview) {
            demoVerdict.accepts = response.toLowerCase() !== "wrong";
            demoVerdict.restart();
            return;
        }
        sddm.login(userName, response, sessionIndex);
    }

    // From SDDM.
    function loginFailed() {
        if (phase !== "verifying")
            return;
        verifyTimeout.stop();
        combo = 0;
        denying = true;
        deniedTimer.restart();
        phase = "ready";
        denied(true);
    }

    function loginSucceeded() {
        verifyTimeout.stop();
        phase = "granted";
        granted();
        cells = 0;
        exitTimer.restart();
    }

    function skip() {
    }

    // ── Lives: the greeter shows none (faillock still applies) ──
    property int maxLives: 0
    property int lives: 0
    readonly property bool lockedOut: false

    // ── Idle: always awake; the ambient clock ticks at ~30 fps ──
    property bool awake: true
    property bool ambient: true
    property real ambientTime: 0

    function poke() {
        awake = true;
    }

    Timer {
        property double last: Date.now()

        interval: 33
        repeat: true
        running: ctx.ambient
        onTriggered: {
            const t = Date.now();
            ctx.ambientTime += Math.min(0.1, (t - last) / 1000);
            last = t;
        }
    }

    // ── Keyboard ──
    readonly property bool capsLock: keyboard.capsLock

    // ── Clock ──
    property date now: new Date()
    readonly property string timeText: Qt.formatTime(now, h24 ? "HH:mm" : "h:mm")

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: ctx.now = new Date()
    }

    // ── Power (the tokens) ──
    function suspend() {
        sddm.suspend();
    }

    function reboot() {
        sddm.reboot();
    }

    function poweroff() {
        sddm.powerOff();
    }

    Timer {
        interval: ctx.introMs
        running: true
        onTriggered: if (ctx.phase === "intro") ctx.phase = "ready"
    }

    Timer {
        id: deniedTimer

        interval: 650
        onTriggered: {
            ctx.denying = false;
            if (ctx.buffer.length === 0)
                ctx.cells = 0;
        }
    }

    // No answer from SDDM: let them try again.
    Timer {
        id: verifyTimeout

        interval: 20000
        onTriggered: {
            if (ctx.phase === "verifying") {
                ctx.message = "No answer from the login service";
                ctx.loginFailed();
            }
        }
    }

    Timer {
        id: exitTimer

        interval: 400
        onTriggered: {
            ctx.phase = "exiting";
            if (ctx.preview)
                again.restart();
        }
    }

    // Test mode: after the exit plays, back to the start, to try again.
    signal restarted

    Timer {
        id: again

        interval: ctx.outroMs + 1200
        onTriggered: {
            ctx.cells = 0;
            ctx.phase = "intro";
            ctx.restarted();
            introAgain.restart();
        }
    }

    Timer {
        id: introAgain

        interval: ctx.introMs
        onTriggered: if (ctx.phase === "intro") ctx.phase = "ready"
    }

    // Test mode (sddm-greeter --test-mode): "wrong" fails, anything else passes.
    Timer {
        id: demoVerdict

        property bool accepts: true

        interval: 700
        onTriggered: accepts ? ctx.loginSucceeded() : ctx.loginFailed()
    }
}
