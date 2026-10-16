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
            key: "launcher.preview"
            kind: "toggle"
            icon: "preview"
            label: "Preview"
            description: "A card beside the results with the selected one's content: file text around the match, pictures, documents, clipboard, emoji, apps, windows."
            def: true
        }
        SettingItem {
            key: "launcher.ask"
            kind: "toggle"
            icon: "auto_awesome"
            section: "Ask Claude"
            label: "Ask Claude from the launcher"
            description: "\"ai <question>\": Enter sends it to Claude through the claude CLI (your login and plan; no tools, nothing saved). Nothing is sent while you type."
            def: true
        }
        SettingItem {
            key: "launcher.askModel"
            kind: "text"
            icon: "psychology"
            label: "Model"
            description: "Empty uses the CLI's default; a short alias like haiku answers faster and costs less."
            placeholder: "haiku"
            def: ""
            shown: root.askOn
        }
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

    readonly property bool askOn: settings.v["launcher.ask"] !== false
    readonly property string askModel: settings.v["launcher.askModel"] ?? ""

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
