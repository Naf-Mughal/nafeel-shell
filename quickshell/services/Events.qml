pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Calendar events: the shell's own (added in the Calendar tab, kept in
// ~/.local/state/nafeel-shell/events.json) and, read only, any synced from
// elsewhere (`external`: Google Calendar's secret iCal addresses, fetched
// every 15 minutes). A reminder comes
// as a notification `remind` minutes before an event's time.
//   { id, title, date: "YYYY-MM-DD", time: "HH:MM" | "", remind: minutes | -1 }
Singleton {
    id: root

    readonly property string path: Quickshell.env("HOME") + "/.local/state/nafeel-shell/events.json"

    readonly property SettingsPage settings: SettingsPage {
        name: "calendar"
        title: "Calendar"
        gloss: "日历"
        icon: "calendar_month"
        order: 45
        description: "Your events, and Google Calendar's (read only)."

        SettingItem {
            key: "calendar.ics"
            icon: "link"
            kind: "text"
            secret: true
            label: "Google Calendar"
            description: "Google Calendar → Settings → a calendar → Integrate calendar → Secret address in iCal format. Paste it here (several: separate them with spaces). Refreshed every 15 minutes."
            placeholder: "https://calendar.google.com/calendar/ical/…/basic.ics"
            def: ""
        }
        SettingItem {
            key: "calendar.remind"
            kind: "number"
            label: "Remind before"
            description: "How long before a timed event its reminder comes."
            def: 10
            min: 0
            max: 120
            step: 5
            unit: " min"
            zeroLabel: "At the time"
        }
    }
    readonly property var urls: (settings.v["calendar.ics"] ?? "").split(/\s+/).filter(u => /^https?:\/\//.test(u))
    readonly property int remindBefore: settings.v["calendar.remind"] ?? 10
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

    // ── Synced calendars (iCal addresses), read only ──
    onUrlsChanged: fetch()
    Component.onCompleted: fetch()
    property Timer refresh: Timer {
        running: root.urls.length > 0
        repeat: true
        interval: 15 * 60000
        onTriggered: root.fetch()
    }

    function fetch(): void {
        if (!urls.length) {
            external = [];
            return;
        }
        fetcher.command = ["sh", "-c", 'for u in "$@"; do curl -sfL --max-time 20 "$u"; echo; done', "sh", ...urls];
        fetcher.running = true;
    }

    property Process fetcher: Process {
        stdout: StdioCollector {
            onStreamFinished: root.external = root.parseIcs(text)
        }
    }

    // iCal's VEVENTs into events, repeats expanded from two months back to a
    // year on (DAILY / WEEKLY with BYDAY / MONTHLY / YEARLY, INTERVAL, COUNT,
    // UNTIL). Times in UTC (Z) are made local; a TZID's are taken as local.
    function parseIcs(text: string): var {
        const lines = text.replace(/\r\n[ \t]/g, "").replace(/\n[ \t]/g, "").split(/\r?\n/);
        const out = [];
        const from = new Date(Date.now() - 60 * 86400000), until = new Date(Date.now() + 365 * 86400000);
        let ev = null;
        const stamp = v => {
            const m = v.match(/^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z)?)?$/);
            if (!m)
                return null;
            if (!m[4])
                return { d: new Date(+m[1], +m[2] - 1, +m[3]), allDay: true };
            const d = m[7] ? new Date(Date.UTC(+m[1], +m[2] - 1, +m[3], +m[4], +m[5])) : new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5]);
            return { d, allDay: false };
        };
        const push = (e, d) => {
            if (d < from || d > until)
                return;
            out.push({
                id: `${e.uid}@${d.getTime()}`,
                title: e.summary || "(no title)",
                date: iso(d),
                time: e.allDay ? "" : `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`,
                remind: e.allDay ? -1 : root.remindBefore,
                external: "Google"
            });
        };
        for (const line of lines) {
            if (line === "BEGIN:VEVENT") {
                ev = {};
                continue;
            }
            if (!ev)
                continue;
            if (line === "END:VEVENT") {
                const st = ev.start;
                if (st && ev.status !== "CANCELLED") {
                    ev.allDay = st.allDay;
                    const rr = ev.rrule;
                    if (!rr) {
                        push(ev, st.d);
                    } else {
                        const f = Object.fromEntries(rr.split(";").map(kv => kv.split("=")));
                        const step = Math.max(1, parseInt(f.INTERVAL ?? "1"));
                        const count = f.COUNT ? parseInt(f.COUNT) : Infinity;
                        const end = f.UNTIL ? (stamp(f.UNTIL)?.d ?? until) : until;
                        // A weekly repeat's days, as days on from the first, in order.
                        const days = f.BYDAY ? f.BYDAY.split(",").map(x => (["SU", "MO", "TU", "WE", "TH", "FR", "SA"].indexOf(x.slice(-2)) - st.d.getDay() + 7) % 7).sort((a, b) => a - b) : null;
                        let n = 0;
                        for (let i = 0; i < 2000 && n < count; i++) {
                            const d = new Date(st.d);
                            if (f.FREQ === "DAILY")
                                d.setDate(d.getDate() + i * step);
                            else if (f.FREQ === "WEEKLY")
                                d.setDate(d.getDate() + Math.floor(i / (days?.length ?? 1)) * 7 * step + (days ? days[i % days.length] : 0));
                            else if (f.FREQ === "MONTHLY")
                                d.setMonth(d.getMonth() + i * step);
                            else if (f.FREQ === "YEARLY")
                                d.setFullYear(d.getFullYear() + i * step);
                            else
                                break;
                            if (d > end || d > until)
                                break;
                            if (d < st.d)
                                continue;
                            n++;
                            if (!(ev.exdates ?? []).includes(d.getTime()))
                                push(ev, d);
                        }
                    }
                }
                ev = null;
                continue;
            }
            const i = line.indexOf(":");
            if (i < 0)
                continue;
            const key = line.slice(0, i).split(";")[0], val = line.slice(i + 1);
            if (key === "SUMMARY")
                ev.summary = val.replace(/\\([,;\\])/g, "$1").replace(/\\n/gi, " ");
            else if (key === "UID")
                ev.uid = val;
            else if (key === "DTSTART")
                ev.start = stamp(val);
            else if (key === "RRULE")
                ev.rrule = val;
            else if (key === "STATUS")
                ev.status = val;
            else if (key === "EXDATE")
                ev.exdates = (ev.exdates ?? []).concat(val.split(",").map(v => stamp(v)?.d?.getTime() ?? 0));
        }
        return out;
    }
}
