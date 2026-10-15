pragma Singleton
import QtQuick

// Shared helpers for the lock surface. Trimmed from the reference shell's
// matugen-driven HUD palette: Cave Abode brings its own colours (Xian.qml).
// No shell imports: the SDDM theme shares this file.
QtObject {
    readonly property string icons: "Material Symbols Rounded"
    readonly property color ink: "#eadfc6"

    // Eased 0..1 slice of a 0..1 timeline: how far an element whose entrance
    // runs from `from` to `to` has got when the whole choreography is at `p`.
    function seg(p, from, to) {
        const x = Math.max(0, Math.min(1, (p - from) / (to - from)));
        return 1 - Math.pow(1 - x, 3);
    }

    // ── Seclusion: wrong incantations in rounds of ten ──
    // Every round of ten wrong ones seals the formation a while; three rounds
    // (a set of thirty) at each length, then the next: 10 s, 30 s, 5 min,
    // 15 min, 30 min, 1 h, 3 h, 6 h, 12 h, then a day for every round after.
    // The lock and the polkit prompt both read it from faillock's tally
    // (kept a week: fail_interval = 604800; pam_faillock's own lock is only a
    // backstop after ten sets, deny = 300, unlock_time = 86400), so they
    // share one count; a success clears it.
    readonly property int roundOf: 10
    readonly property int roundsPerSet: 3
    readonly property int window: 604800
    readonly property var seclusions: [10, 30, 300, 900, 1800, 3600, 10800, 21600, 43200, 86400]

    function _sealFor(round) {
        return seclusions[Math.min(Math.floor((round - 1) / roundsPerSet), seclusions.length - 1)];
    }

    // `faillock --user` output: the valid failures' times (epoch ms).
    function failureTimes(text) {
        const out = [];
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const m = lines[i].match(/^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})\s.*\s([VI])\s*$/);
            if (m && m[7] === "V")
                out.push(new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6]).getTime());
        }
        return out;
    }

    // From the failures' times: { failures, lives (left this round), until
    // (epoch ms the seal reopens, 0 = open), next (seconds the next full
    // round would seal it) }.
    function seclusion(times, now) {
        const n = times.length;
        const rounds = Math.floor(n / roundOf);
        const latest = n > 0 ? Math.max.apply(null, times) : 0;
        let until = 0;
        if (rounds > 0 && n % roundOf === 0) {
            const t = latest + _sealFor(rounds) * 1000;
            if (t > now)
                until = t;
        }
        return {
            failures: n,
            lives: until > 0 ? 0 : roundOf - n % roundOf,
            until: until,
            next: _sealFor(rounds + 1)
        };
    }

    // "10 seconds", "5 minutes", "1 hour".
    function span(s) {
        const u = s >= 3600 ? [3600, "hour"] : s >= 60 ? [60, "minute"] : [1, "second"];
        const v = Math.round(s / u[0]);
        return v + " " + u[1] + (v === 1 ? "" : "s");
    }

    // A countdown: "0:09", "4:59", "2:59:59".
    function clock(s) {
        const h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, sec = s % 60;
        return (h > 0 ? h + ":" + String(m).padStart(2, "0") : String(m)) + ":" + String(sec).padStart(2, "0");
    }
}
