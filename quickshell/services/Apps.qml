pragma Singleton

// Installed applications (.desktop entries): fuzzy search, launching, and
// matching umbriel's app ids to entries for icons and names.

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property var list: DesktopEntries.applications.values.filter(a => !a.noDisplay).sort((a, b) => a.name.localeCompare(b.name))

    // Subsequence match with bonuses for word starts and runs; 0 = no match.
    function score(text: string, query: string): real {
        text = text.toLowerCase();
        if (text.startsWith(query))
            return 100 + query.length;
        if (text.includes(query))
            return 60 + query.length;
        let s = 0, ti = 0, run = 0;
        for (const ch of query) {
            const at = text.indexOf(ch, ti);
            if (at < 0)
                return 0;
            run = at === ti ? run + 1 : 0;
            s += 1 + run + (at === 0 || " -_.".includes(text[at - 1]) ? 3 : 0);
            ti = at + 1;
        }
        return s;
    }

    function search(query: string): var {
        query = query.trim().toLowerCase();
        if (!query)
            return list;
        return list.map(a => ({
                    app: a,
                    s: Math.max(score(a.name, query), score(a.genericName ?? "", query) * 0.8, (a.keywords ?? []).reduce((m, k) => Math.max(m, score(k, query) * 0.6), 0), score(a.id, query) * 0.5)
                })).filter(r => r.s > 0).sort((x, y) => y.s - x.s).map(r => r.app);
    }

    function launch(app: var): void {
        app.execute();
    }

    // The desktop entry for an umbriel app id (window class), or null: by id,
    // reverse-DNS id ("dolphin" -> org.kde.dolphin), StartupWMClass, then
    // Quickshell's heuristic.
    function forAppId(appId: string): var {
        if (!appId)
            return null;
        const id = appId.toLowerCase();
        return DesktopEntries.byId(appId) ?? DesktopEntries.applications.values.find(a => a.id.toLowerCase().endsWith("." + id) || (a.startupClass ?? "").toLowerCase() === id) ?? DesktopEntries.heuristicLookup(appId);
    }

    // What kind of app it is, from its desktop entry's categories (the
    // freedesktop ones), as a Material Symbol and the colour role its tile
    // takes: the first match wins. No match: null (the app's own icon is
    // used, tinted).
    readonly property var kinds: [
        {
            cats: ["WebBrowser"],
            glyph: "public",
            role: "primary"
        },
        {
            cats: ["TerminalEmulator"],
            glyph: "terminal",
            role: "secondary"
        },
        {
            cats: ["FileManager"],
            glyph: "folder",
            role: "tertiary"
        },
        {
            cats: ["IDE", "TextEditor", "Development"],
            glyph: "code",
            role: "primary"
        },
        {
            cats: ["Email"],
            glyph: "mail",
            role: "secondary"
        },
        {
            cats: ["Chat", "InstantMessaging", "IRCClient"],
            glyph: "forum",
            role: "tertiary"
        },
        {
            cats: ["Music", "Audio", "Player"],
            glyph: "music_note",
            role: "secondary"
        },
        {
            cats: ["Video", "AudioVideo", "Recorder"],
            glyph: "play_circle",
            role: "tertiary"
        },
        {
            cats: ["Graphics", "Photography", "RasterGraphics", "VectorGraphics", "2DGraphics", "3DGraphics"],
            glyph: "brush",
            role: "primary"
        },
        {
            cats: ["Game"],
            glyph: "sports_esports",
            role: "secondary"
        },
        {
            cats: ["Office", "WordProcessor", "Spreadsheet", "Presentation"],
            glyph: "description",
            role: "tertiary"
        },
        {
            cats: ["Calculator"],
            glyph: "calculate",
            role: "secondary"
        },
        {
            cats: ["Settings", "DesktopSettings", "HardwareSettings"],
            glyph: "settings",
            role: "secondary"
        },
        {
            cats: ["Monitor", "System"],
            glyph: "monitor_heart",
            role: "secondary"
        }
    ]

    function kind(appId: string): var {
        const entry = forAppId(appId);
        const raw = entry?.categories ?? [];
        const cats = (Array.isArray(raw) ? raw : String(raw).split(/[;,]/)).map(c => String(c).trim()).filter(Boolean);
        return kinds.find(k => k.cats.some(c => cats.includes(c))) ?? null;
    }

    function icon(appId: string): string {
        const entry = forAppId(appId);
        return Quickshell.iconPath(entry?.icon || appId, "application-x-executable");
    }
}
