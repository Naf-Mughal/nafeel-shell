import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Nafeel
import qs.components
import qs.services

// The system and the shell's own doings: session (lock, sleep, log out,
// restart, shut down: the last three asked twice), caffeine, night light,
// power profiles, the shell's panels.
LauncherProvider {
    name: "System"
    keyword: "s"
    weight: 1.1

    function panel(name: string): void {
        ShellState.anchorTo(name);
        ShellState.pin(name, Umbriel.focusedOutput);
    }

    readonly property var items: [
        { title: "Lock", words: "lock screen", icon: "lock", run: () => Session.run("lock") },
        { title: "Sleep", words: "suspend sleep", icon: "bedtime", run: () => Session.run("suspend") },
        { title: "Log out", words: "logout sign out exit session", icon: "logout", confirm: "Log out", run: () => Session.run("logout") },
        { title: "Restart", words: "reboot restart", icon: "restart_alt", confirm: "Restart", run: () => Session.run("reboot") },
        { title: "Shut down", words: "shutdown power off poweroff", icon: "power_settings_new", confirm: "Shut down", run: () => Session.run("shutdown") },
        { title: "Caffeine", words: "keep awake stay awake no sleep caffeine", icon: "coffee", run: () => Display.toggleCaffeine(), state: () => Display.caffeine },
        { title: "Night light", words: "night light warm blue light filter", icon: "nightlight", run: () => Display.toggleNightLight(), state: () => Display.nightLight },
        { title: "Power profile: Performance", words: "performance power profile fast", icon: "speed", run: () => PowerProfiles.profile = PowerProfile.Performance },
        { title: "Power profile: Balanced", words: "balanced power profile", icon: "balance", run: () => PowerProfiles.profile = PowerProfile.Balanced },
        { title: "Power profile: Power saver", words: "power saver battery saver profile", icon: "battery_saver", run: () => PowerProfiles.profile = PowerProfile.PowerSaver },
        { title: "Settings", words: "settings preferences config", icon: "settings", run: () => panel("settings") },
        { title: "Wallpaper", words: "wallpaper picker background", icon: "wallpaper", run: () => panel("wallpapers") },
        { title: "Notes", words: "notes scratchpad", icon: "edit_note", run: () => panel("notes") },
        { title: "Overview", words: "overview workspaces expose", icon: "overview", run: () => Umbriel.dispatch("overview-toggle") }
    ]

    function query(text: string, seq: int): var {
        if (text === "")
            return [];
        const out = [];
        for (const it of items) {
            const s = Math.max(Fuzzy.score(it.title, text), Fuzzy.score(it.words, text) * 0.8);
            if (s <= 0)
                continue;
            const on = it.state?.();
            out.push({
                title: it.title,
                subtitle: it.confirm ? "Asks before doing it" : on === true ? "On: Enter turns it off" : on === false ? "Off: Enter turns it on" : "",
                icon: it.icon,
                score: s,
                key: "system:" + it.title,
                confirm: it.confirm ?? "",
                run: it.run
            });
        }
        return out;
    }
}
