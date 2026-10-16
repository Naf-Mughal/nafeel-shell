import QtQuick
import Quickshell
import Nafeel
import qs.components
import qs.services

// Open windows, by title or app: Enter goes to it (its workspace too).
LauncherProvider {
    name: "Windows"
    icon: "select_window"
    keyword: "w"
    weight: 1.05

    function query(text: string, seq: int): var {
        const out = [];
        for (const w of Umbriel.windows) {
            const app = Apps.forAppId(w.app_id);
            const appName = app?.name ?? w.app_id ?? "";
            const title = Umbriel.titleOf(w) || appName;
            const s = text === "" ? 1 : Math.max(Fuzzy.score(title, text), Fuzzy.score(appName, text) * 0.9);
            if (s <= 0)
                continue;
            const ws = Umbriel.workspaces.find(x => x.id === w.workspace);
            out.push({
                title: title,
                subtitle: `${appName}${ws ? " · workspace " + (ws.name || ws.index) : ""}`,
                image: app?.icon ?? w.app_id,
                preview: { kind: "window", id: w.id, title: title, lines: [appName] },
                score: s,
                key: "", // windows come and go: not ranked by use
                run: () => Umbriel.focusWindow(w),
                actions: [
                    {
                        label: "Close window",
                        icon: "close",
                        run: () => Umbriel.dispatch("window-close:" + w.id)
                    }
                ]
            });
        }
        return out;
    }
}
