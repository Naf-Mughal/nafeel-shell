pragma Singleton

// The shell's notification server (org.freedesktop.Notifications; the plugin
// turns Noctalia's off while the shell runs).
//
//   history  every notification, newest first (the last ones are kept across
//            restarts in ~/.local/state/nafeel-shell/notifications.json,
//            without their buttons, which only live as long as the sender)
//   popups   the ones showing as toasts; a toast hides after its timeout but
//            the notification stays open in history, so its buttons still
//            work (capture's "open / edit / folder" wait for that)
//   dnd      toasts off, except critical ones
//
// Entry: { key, app, summary, body, image, icon, time, urgency, seen,
//          popup, notif (the live Notification, or null), actions }

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.config
import qs.services

Singleton {
    id: root

    readonly property string stateFile: Quickshell.env("HOME") + "/.local/state/nafeel-shell/notifications.json"
    // The Settings panel's Notifications page.
    readonly property SettingsPage settings: SettingsPage {
        name: "notifications"
        title: "Notifications"
        gloss: "通知"
        icon: "notifications"
        order: 50
        description: "Toasts and the history."

        SettingItem {
            key: "notifs.timeout"
            kind: "number"
            label: "Toasts stay for"
            description: "When the app doesn't say how long. Critical ones stay until dismissed."
            def: 6
            min: 2
            max: 30
            step: 1
            unit: " s"
        }
        SettingItem {
            key: "notifs.respectAppTimeout"
            kind: "toggle"
            icon: "timer"
            label: "Use the app's own timeout"
            description: "Off: every toast stays for the time above."
            def: true
        }
        SettingItem {
            key: "notifs.maxShown"
            kind: "number"
            label: "Toasts at once"
            def: 4
            min: 1
            max: 8
            step: 1
        }
        SettingItem {
            key: "notifs.history"
            kind: "number"
            section: "History"
            label: "Kept"
            description: "How many notifications are kept across restarts."
            def: 100
            min: 20
            max: 500
            step: 10
        }
    }
    readonly property int maxHistory: settings.v["notifs.history"]
    readonly property int defaultTimeout: settings.v["notifs.timeout"] * 1000
    readonly property int maxShown: settings.v["notifs.maxShown"]

    property var history: []
    property bool dnd: false
    property int nextKey: 1
    // Toast countdowns pause while the pointer is on any toast.
    property bool hoveringPopups: false

    readonly property var popups: history.filter(n => n.popup)
    readonly property int unread: history.filter(n => !n.seen).length

    // [{ app, items: [entry…] }], the app with the newest first.
    readonly property var groups: {
        const out = [];
        const byApp = {};
        for (const n of history) {
            if (!byApp[n.app]) {
                byApp[n.app] = {
                    app: n.app,
                    items: []
                };
                out.push(byApp[n.app]);
            }
            byApp[n.app].items.push(n);
        }
        return out;
    }

    function update(): void {
        history = history.slice();
        saveTimer.restart();
    }

    function markSeen(): void {
        if (history.some(n => !n.seen)) {
            for (const n of history)
                n.seen = true;
            update();
        }
    }

    function toggleDnd(): void {
        dnd = !dnd;
        saveTimer.restart();
    }

    function hidePopup(n: var): void {
        n.popup = false;
        update();
    }

    // Run an action (or the "default" one), then close the notification.
    function invoke(n: var, identifier: string): void {
        const action = n.notif?.actions.find(a => a.identifier === (identifier || "default"));
        if (action)
            action.invoke();
        if (n.notif && !n.notif.resident)
            remove(n);
        else
            hidePopup(n);
    }

    function remove(n: var): void {
        n.notif?.dismiss();
        history = history.filter(x => x !== n);
        saveTimer.restart();
    }

    function clear(): void {
        for (const n of history)
            n.notif?.dismiss();
        history = [];
        saveTimer.restart();
    }

    function imageOf(notif: var): string {
        if (notif.image)
            return notif.image.startsWith("/") ? "file://" + notif.image : notif.image;
        const path = notif.hints?.["image-path"] ?? "";
        return path.startsWith("/") ? "file://" + path : path.startsWith("file://") ? path : "";
    }

    function add(notif: var): void {
        notif.tracked = true;
        const timeout = notif.expireTimeout > 0 && root.settings.v["notifs.respectAppTimeout"] ? notif.expireTimeout : root.defaultTimeout;
        const existing = history.find(n => n.notif === notif);
        const entry = existing ?? {
            key: root.nextKey++,
            notif: notif
        };
        entry.app = notif.appName || "Notification";
        entry.summary = notif.summary;
        entry.body = notif.body;
        entry.image = imageOf(notif);
        entry.icon = notif.appIcon;
        entry.time = Date.now();
        entry.urgency = notif.urgency;
        entry.actions = notif.actions.filter(a => a.identifier !== "default").map(a => ({
                    identifier: a.identifier,
                    text: a.text
                }));
        entry.seen = false;
        entry.popup = !root.dnd || notif.urgency === NotificationUrgency.Critical;
        // Critical ones stay until dismissed.
        entry.expiresAt = notif.urgency === NotificationUrgency.Critical ? 0 : Date.now() + timeout;

        if (!existing) {
            notif.closed.connect(() => {
                entry.notif = null;
                entry.actions = [];
                entry.popup = false;
                root.update();
            });
        }

        history = existing ? history.slice() : [entry, ...history].slice(0, root.maxHistory);
        saveTimer.restart();
    }

    // For keybinds:  qs -p <shell> ipc call notifs invokeLatest | dismissLatest | clear | toggleDnd
    //                qs -p <shell> ipc call notifs action <identifier>   (on the newest that has it)
    IpcHandler {
        target: "notifs"

        function invokeLatest(): void {
            const n = root.history.find(n => n.notif);
            if (n)
                root.invoke(n, "default");
        }

        function action(identifier: string): void {
            const n = root.history.find(n => n.notif?.actions.some(a => a.identifier === identifier));
            if (n)
                root.invoke(n, identifier);
        }

        function dismissLatest(): void {
            const n = root.popups[0] ?? root.history[0];
            if (n)
                root.remove(n);
        }

        function clear(): void {
            root.clear();
        }

        function toggleDnd(): void {
            root.toggleDnd();
        }
    }

    NotificationServer {
        keepOnReload: true
        actionsSupported: true
        actionIconsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notif => root.add(notif)
    }

    // Toast countdowns (paused while hovered).
    Timer {
        running: root.popups.length > 0
        interval: 250
        repeat: true
        onTriggered: {
            const now = Date.now();
            if (root.hoveringPopups) {
                for (const n of root.popups)
                    if (n.expiresAt > 0)
                        n.expiresAt += interval;
                return;
            }
            const due = root.popups.filter(n => n.expiresAt > 0 && n.expiresAt <= now);
            if (due.length > 0) {
                for (const n of due)
                    n.popup = false;
                root.update();
            }
        }
    }

    // Saved a moment after a change; loaded once at start.
    Timer {
        id: saveTimer

        interval: 1000
        onTriggered: store.setText(JSON.stringify({
                dnd: root.dnd,
                history: root.history.map(n => ({
                            app: n.app,
                            summary: n.summary,
                            body: n.body,
                            image: n.image.startsWith("file://") ? n.image : "",
                            icon: n.icon,
                            time: n.time,
                            urgency: n.urgency,
                            seen: n.seen
                        }))
            }))
    }

    FileView {
        id: store

        path: root.stateFile
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.dnd = !!d.dnd;
                const restored = (d.history ?? []).map(n => Object.assign(n, {
                        key: root.nextKey++,
                        notif: null,
                        actions: [],
                        popup: false,
                        expiresAt: 0
                    }));
                root.history = [...root.history, ...restored].slice(0, root.maxHistory);
            } catch (e) {}
        }
    }
}
