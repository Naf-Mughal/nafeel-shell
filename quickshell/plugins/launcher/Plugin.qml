import QtQuick
import Quickshell
import qs.config

// The launcher plugin's root (Plugins.instance("launcher")): its settings.
// The files plugin adds its own section to the same Settings page.
Scope {
    id: root

    readonly property SettingsPage settings: SettingsPage {
        name: "launcher"
        title: "Launcher"
        gloss: "启"
        icon: "search"
        order: 33
        description: "What the command center's search looks through."

        SettingItem {
            key: "launcher.webKeywords"
            kind: "text"
            icon: "language"
            section: "Web"
            label: "Web keywords"
            description: "Your own searches, one after another: keyword=Name|address with %s where the search goes. Built in: g yt gh maps wiki aur arch npm mdn so tr img."
            placeholder: "rd=Reddit|https://www.reddit.com/search/?q=%s ; imdb=IMDb|https://www.imdb.com/find/?q=%s"
            def: ""
        }
    }

    // keyword -> [name, "language", url].
    readonly property var webKeywords: {
        const out = {};
        for (const part of (settings.v["launcher.webKeywords"] ?? "").split(/\s*;\s*/)) {
            const m = /^(\w+)\s*=\s*([^|]+)\|(.+)$/.exec(part.trim());
            if (m && m[3].includes("%s"))
                out[m[1]] = [m[2].trim(), "language", m[3].trim()];
        }
        return out;
    }
}
