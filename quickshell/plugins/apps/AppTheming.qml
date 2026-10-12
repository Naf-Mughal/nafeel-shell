// Qt and KDE apps (Dolphin, …) in the shell's colours, as the app-theming
// plugin did: Qt apps reach the KDE colour scheme the theme writes
// (~/.local/share/color-schemes/noctalia.colors, nafeel-theme's kcolorscheme
// template) through the qtengine platform theme. The shell writes
//
//   ~/.config/umbriel/plugins/app-theming.toml  [environment]
//       QT_QPA_PLATFORMTHEME=qtengine (included from umbriel's config; apps
//       started after the next login get it)
//   ~/.config/qtengine/config.json  the scheme, icon theme, style and fonts
//
// from the Theme page's "Qt and KDE apps" section, only when they change.
// The icon themes and styles offered are the ones installed.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

Scope {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string scheme: home + "/.local/share/color-schemes/noctalia.colors"

    // Installed: [{ value, icon, label }].
    property var iconThemes: []
    property var styles: [
        {
            value: "Fusion",
            icon: "widgets",
            label: "Fusion"
        }
    ]

    readonly property SettingsPage settings: SettingsPage {
        name: "theme"
        order: 16

        SettingItem {
            key: "apps.qt"
            kind: "toggle"
            icon: "widgets"
            section: "Qt and KDE apps"
            label: "Follow the theme"
            description: "Qt apps like Dolphin take the palette through qtengine (apps started after the next login)."
            def: true
        }
        SettingItem {
            key: "apps.iconTheme"
            label: "Icon theme"
            def: "breeze-dark"
            options: root.iconThemes
            shown: root.qt
        }
        SettingItem {
            key: "apps.style"
            label: "Widget style"
            def: "Darkly"
            options: root.styles
            shown: root.qt
        }
        SettingItem {
            key: "apps.font"
            kind: "text"
            label: "Font"
            placeholder: "Sans Serif"
            def: "Sans Serif"
            shown: root.qt
        }
        SettingItem {
            key: "apps.fixedFont"
            kind: "text"
            label: "Fixed-width font"
            placeholder: "Monospace"
            def: "Monospace"
            shown: root.qt
        }
        SettingItem {
            key: "apps.fontSize"
            kind: "number"
            label: "Font size"
            def: 11
            min: 8
            max: 18
            step: 1
            unit: " pt"
            shown: root.qt
        }
        SettingItem {
            key: "apps.singleClick"
            kind: "toggle"
            icon: "ads_click"
            label: "Open with one click"
            description: "Files and folders open on a single click instead of a double one."
            def: false
            shown: root.qt
        }
    }

    readonly property bool qt: settings.v["apps.qt"] === true

    readonly property string envText: "# Written by the shell (plugins/apps/AppTheming.qml); edits here are overwritten.\n" + (qt ? "[environment]\nQT_QPA_PLATFORMTHEME = \"qtengine\"\n" : "# Qt apps don't follow the theme (Settings: Theme).\n")
    readonly property string qtengineText: JSON.stringify({
        theme: {
            colorScheme: scheme,
            iconTheme: settings.v["apps.iconTheme"],
            style: settings.v["apps.style"],
            font: {
                family: settings.v["apps.font"].trim() || "Sans Serif",
                size: settings.v["apps.fontSize"],
                weight: -1
            },
            fontFixed: {
                family: settings.v["apps.fixedFont"].trim() || "Monospace",
                size: settings.v["apps.fontSize"],
                weight: -1
            }
        },
        misc: {
            menusHaveIcons: true,
            singleClickActivate: settings.v["apps.singleClick"] === true,
            shortcutsForContextMenus: true
        }
    }, null, 4) + "\n"

    onEnvTextChanged: write(envFile, envText)
    onQtengineTextChanged: write(qtengineFile, qtengineText)

    // Only once the settings are read, and only when it differs.
    function write(file: FileView, text: string): void {
        if (!Settings.loaded || !file.ready || file.current === text)
            return;
        file.setText(text);
        file.current = text;
    }

    Connections {
        target: Settings

        function onLoadedChanged(): void {
            root.write(envFile, root.envText);
            root.write(qtengineFile, root.qtengineText);
        }
    }

    FileView {
        id: envFile

        property string current: ""
        property bool ready: false

        path: root.home + "/.config/umbriel/plugins/app-theming.toml"
        printErrors: false
        onLoaded: {
            current = text();
            ready = true;
            root.write(envFile, root.envText);
        }
        onLoadFailed: {
            ready = true;
            root.write(envFile, root.envText);
        }
    }

    FileView {
        id: qtengineFile

        property string current: ""
        property bool ready: false

        path: root.home + "/.config/qtengine/config.json"
        printErrors: false
        onLoaded: {
            current = text();
            ready = true;
            root.write(qtengineFile, root.qtengineText);
        }
        onLoadFailed: {
            ready = true;
            Quickshell.execDetached(["mkdir", "-p", root.home + "/.config/qtengine"]);
            root.write(qtengineFile, root.qtengineText);
        }
    }

    // What's installed: icon themes (an index.theme listing icon directories,
    // so not cursor-only themes) and Qt widget styles.
    Process {
        running: true
        command: ["sh", "-c", 'for d in "$HOME/.local/share/icons"/* "$HOME/.icons"/* /usr/share/icons/*; do grep -qs "^Directories=" "$d/index.theme" && basename "$d"; done | sort -u']
        stdout: StdioCollector {
            onStreamFinished: root.iconThemes = text.trim().split("\n").filter(Boolean).filter(n => n !== "default").map(n => ({
                        value: n,
                        icon: "interests",
                        label: n
                    }))
        }
    }

    Process {
        running: true
        command: ["sh", "-c", 'for d in /usr/lib/qt6/plugins/styles /usr/lib/x86_64-linux-gnu/qt6/plugins/styles; do ls "$d" 2>/dev/null; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const names = {
                    darkly6: "Darkly",
                    breeze6: "Breeze",
                    kvantum: "kvantum",
                    oxygen6: "Oxygen"
                };
                const found = text.trim().split("\n").map(f => f.replace(/^lib/, "").replace(/\.so$/, "")).filter(n => names[n]).map(n => ({
                            value: names[n],
                            icon: "style",
                            label: names[n]
                        }));
                root.styles = found.concat([
                    {
                        value: "Fusion",
                        icon: "widgets",
                        label: "Fusion"
                    }
                ]);
            }
        }
    }
}
