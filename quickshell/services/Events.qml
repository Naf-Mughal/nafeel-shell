pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Calendar events: the shell's own (added in the Calendar tab, kept in
// ~/.local/state/nafeel-shell/events.json) and, read only, any synced from
// elsewhere (`external`, e.g. Google through vdirsyncer). A reminder comes
// as a notification `remind` minutes before an event's time.
//   { id, title, date: "YYYY-MM-DD", time: "HH:MM" | "", remind: minutes | -1 }
Singleton {
    id: root

    readonly property string path: Quickshell.env("HOME") + "/.local/state/nafeel-shell/events.json"
    property var own: []
    property var external: []
    readonly property var all: own.concat(external)

    function iso(d: date): string {
        return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
    }

    // A day's events, timed ones in order, all-day first.
    function on(dateIso: string): var {
        return all.filter(e => e.date === dateIso).sort((a, b) => (a.time || "").localeCompare(b.time || ""));
    }

    function add(title: string, dateIso: string, time: string, remind: int): void {
        title = title.trim();
        if (!title)
            return;
        own = own.concat([{
                    id: `${Date.now()}`,
                    title,
                    date: dateIso,
                    time: /^\d{1,2}:\d{2}$/.test(time.trim()) ? time.trim().padStart(5, "0") : "",
                    remind: remind
                }]);
        save();
    }

    function remove(id: string): void {
        own = own.filter(e => e.id !== id);
        save();
    }

    function save(): void {
        file.setText(JSON.stringify({
            events: own
        }, null, 2) + "\n");
    }

    property FileView file: FileView {
        path: root.path
        printErrors: false
        // Edits from outside are picked up too.
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.own = JSON.parse(text()).events ?? [];
            } catch (e) {
                root.own = [];
            }
        }
    }

    // Reminders: each once, when its moment comes (checked twice a minute).
    property var _reminded: ({})
    property Timer reminders: Timer {
        running: true
        repeat: true
        interval: 30000
        triggeredOnStart: true
        onTriggered: {
            const now = Date.now();
            for (const e of root.all) {
                if (!e.time || (e.remind ?? -1) < 0 || root._reminded[e.id])
                    continue;
                const start = new Date(`${e.date}T${e.time}:00`).getTime();
                const at = start - e.remind * 60000;
                if (now >= at && now < start + 60000) {
                    root._reminded[e.id] = true;
                    Quickshell.execDetached(["notify-send", "-a", "Calendar", "-i", "x-office-calendar", e.title, e.remind > 0 ? `In ${e.remind} min, at ${e.time}` : `Now, ${e.time}`]);
                }
            }
        }
    }
}
