pragma Singleton

// Who and where: display name, user@host, uptime and the current wallpaper
// (Wallpapers.current). And the session
// actions, run by the shell itself: lock (the shell's lock), suspend (lock,
// then sleep), and log out / restart / shut down done gracefully, as the
// graceful-power plugin did: every window is asked to close first (apps save
// their session or ask about unsaved work), and if any hold out after the
// grace time a notification says which, with "Restart anyway" / "Cancel";
// closing the holdouts yourself carries on by itself. The Settings panel's
// Session & lock page sets whether and how long.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property string user: Quickshell.env("USER")
    readonly property string home: Quickshell.env("HOME")
    property string realName: ""
    property string host: ""
    // A picture of it (a live wallpaper's frame), for the home tab and the
    // workspaces.
    readonly property string wallpaper: Wallpapers.stillOf(Wallpapers.current)
    property real uptime: 0 // seconds

    readonly property SettingsPage settings: SettingsPage {
        name: "session"
        title: "Session & lock"
        gloss: "起居"
        icon: "power_settings_new"
        order: 38
        description: "Signing out, restarting and shutting down; the lock."

        SettingItem {
            key: "session.closeAppsFirst"
            kind: "toggle"
            icon: "close"
            section: "Restart, shut down, sign out"
            label: "Close apps first"
            description: "Every window is asked to close (apps save, or ask about unsaved work) before going ahead."
            def: true
        }
        SettingItem {
            key: "session.grace"
            kind: "number"
            label: "Wait for apps"
            description: "How long apps get to close on their own."
            def: 10
            min: 2
            max: 60
            step: 1
            unit: " s"
            shown: root.settings.v["session.closeAppsFirst"] === true
        }
        SettingItem {
            key: "session.promptWait"
            kind: "number"
            label: "Then ask for"
            description: "If apps hold out, how long the notice waits for an answer before cancelling."
            def: 120
            min: 30
            max: 600
            step: 30
            format: "duration"
            shown: root.settings.v["session.closeAppsFirst"] === true
        }
    }

    // A graceful restart / shut down / sign out underway ("" when none).
    property string pending: ""
    property var pendingCommand: []
    readonly property var verbs: ({
            reboot: "Restart",
            shutdown: "Shut down",
            logout: "Sign out"
        })

    // The shell's lock listens for this (Lock.qml).
    signal lockRequested

    // For keybinds: qs -p <shell> ipc call session run <action>
    IpcHandler {
        target: "session"

        function run(action: string): void {
            root.run(action);
        }
    }

    // lock | suspend | logout | reboot | shutdown
    function run(action: string): void {
        switch (action) {
        case "lock":
            lockRequested();
            break;
        case "suspend":
            lockRequested();
            Quickshell.execDetached(["sh", "-c", "sleep 0.6; systemctl suspend"]);
            break;
        case "logout":
        case "reboot":
        case "shutdown":
            graceful(action);
            break;
        }
    }

    function graceful(action: string): void {
        if (pending)
            return;
        const command = action === "reboot" ? ["systemctl", "reboot"] : action === "shutdown" ? ["systemctl", "poweroff"] : ["umbriel", "msg", "session-quit:skip-confirmation"];
        if (!settings.v["session.closeAppsFirst"] || Umbriel.windows.length === 0) {
            Quickshell.execDetached(command);
            return;
        }
        pending = action;
        pendingCommand = command;
        for (const w of Umbriel.windows)
            Umbriel.dispatch(`window-close:${w.id}`);
        grace.interval = settings.v["session.grace"] * 1000;
        grace.restart();
    }

    function _goAhead(): void {
        const command = pendingCommand;
        _stop();
        Quickshell.execDetached(command);
    }

    function _stop(): void {
        pending = "";
        grace.stop();
        promptTimer.stop();
        prompt.running = false;
    }

    function _cancel(): void {
        const verb = verbs[pending] ?? "Restart";
        _stop();
        Quickshell.execDetached(["notify-send", "--app-name=Power", `${verb} cancelled`, "Your apps were left open."]);
    }

    // Every window gone (closed on its own or by you): go ahead.
    Connections {
        target: Umbriel

        function onWindowsChanged(): void {
            if (root.pending && Umbriel.windows.length === 0)
                root._goAhead();
        }
    }

    // Some held out: say which, and wait for an answer.
    Timer {
        id: grace

        onTriggered: {
            const apps = [...new Set(Umbriel.windows.map(w => w.app_id || "an app"))].join(", ");
            const verb = root.verbs[root.pending];
            const n = Umbriel.windows.length;
            prompt.command = ["notify-send", "--app-name=Power", "-u", "critical", "-i", "system-reboot", "-A", `force=${verb} anyway`, "-A", "cancel=Cancel", `${n} app${n === 1 ? " is" : "s are"} preventing ${verb.toLowerCase()}`, `Still open: ${apps}. Save your work and close them, or choose ${verb} anyway.`];
            prompt.running = true;
            promptTimer.interval = root.settings.v["session.promptWait"] * 1000;
            promptTimer.restart();
        }
    }

    Timer {
        id: promptTimer

        onTriggered: root._cancel()
    }

    Process {
        id: prompt

        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.pending)
                    return;
                if (text.trim() === "force")
                    root._goAhead();
                else
                    root._cancel();
            }
        }
    }

    Process {
        running: true
        command: ["sh", "-c", 'getent passwd "$USER" | cut -d: -f5 | cut -d, -f1; cat /etc/hostname']
        stdout: StdioCollector {
            onStreamFinished: {
                const [name, host] = text.split("\n");
                root.realName = name || root.user;
                root.host = host ?? "";
            }
        }
    }

    FileView {
        id: uptimeFile

        path: "/proc/uptime"
        onLoaded: root.uptime = parseFloat(text()) || 0
    }

    Timer {
        running: true
        repeat: true
        interval: 60000
        triggeredOnStart: true
        onTriggered: uptimeFile.reload()
    }

    function formatUptime(): string {
        const s = uptime, d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return `${d > 0 ? d + " d " : ""}${h > 0 ? h + " h " : ""}${m} min`;
    }
}
