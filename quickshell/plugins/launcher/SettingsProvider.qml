import QtQuick
import Quickshell
import Nafeel
import qs.config
import qs.components
import qs.services

// The shell's settings: every page and every setting on it, by its label
// and by what its description says ("blur", "battery", "font"). Enter opens
// Settings on that page.
LauncherProvider {
    name: "Settings"
    keyword: "set"
    weight: 0.9

    function open(page: string): void {
        ShellState.settingsPage = page;
        ShellState.anchorTo("settings");
        ShellState.pin("settings", Umbriel.focusedOutput);
    }

    function query(text: string, seq: int): var {
        if (text === "")
            return [];
        const out = [];
        for (const page of Settings.pages) {
            const title = page.title || page.name;
            const ps = Math.max(Fuzzy.score(title, text), Fuzzy.score(page.description ?? "", text) * 0.5);
            if (ps > 0)
                out.push({
                    title: title,
                    subtitle: "Settings page",
                    icon: page.icon || "settings",
                    score: ps,
                    key: "settings:" + page.name,
                    run: () => open(page.name)
                });
            for (const item of Settings.itemsOf(page.name)) {
                if (!item.label)
                    continue;
                const s = Math.max(Fuzzy.score(item.label, text), Fuzzy.score(item.section ?? "", text) * 0.5, Fuzzy.score(item.description ?? "", text) * 0.45);
                if (s <= 0)
                    continue;
                out.push({
                    title: item.label,
                    subtitle: `${title}${item.section ? " · " + item.section : ""}${item.description ? " — " + item.description : ""}`,
                    icon: item.icon && item.icon !== "tune" ? item.icon : "tune",
                    score: s,
                    key: "setting:" + item.key,
                    run: () => open(page.name)
                });
            }
        }
        return out;
    }
}
