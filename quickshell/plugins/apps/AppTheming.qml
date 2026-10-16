// Qt and KDE apps (Dolphin, …) in the shell's colours: they run on KDE's
// platform theme (plasma-integration), which reads the colour scheme
// nafeel-theme merges into kdeglobals, and the style, icons and fonts set
// here. KDE's rather than qtengine since 2026-10-16: under qtengine the
// Darkly style's translucency never took (Translucent Qt/KDE apps), and it
// needed a rebuild on every Qt minor update. The shell writes
//
//   ~/.config/umbriel/plugins/app-theming.toml  [environment]
//       QT_QPA_PLATFORMTHEME=kde (included from umbriel's config; umbriel
//       applies it at login), and the same now to the systemd/D-Bus
//       activation environment; the shell's own launches get it from
//       bin/shell-env at its next start (the shell itself stays on qtengine:
//       an Env pragma in shell.qml)
//   ~/.config/kdeglobals  [KDE] widgetStyle, SingleClick, [Icons] Theme,
//       [General] font / fixed (kwriteconfig6)
//   ~/.config/qtengine/config.json  the same for the shell's own qtengine
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
            description: "Qt and KDE apps like Dolphin take the palette, style, icons and fonts (KDE's platform theme; reopen apps to see it)."
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
            key: "apps.singleClick"
            kind: "toggle"
            icon: "ads_click"
            label: "Open with one click"
            description: "Files and folders open on a single click instead of a double one."
            def: false
            shown: root.qt
        }
        SettingItem {
            key: "apps.font"
            kind: "text"
            icon: "match_case"
            section: "Fonts"
            label: "Font"
            description: "System-wide: the shell, Qt and GTK apps, and everything that asks for the default sans (browsers, Electron apps)."
            placeholder: "Noto Sans"
            def: "Noto Sans"
        }
        SettingItem {
            key: "apps.fixedFont"
            kind: "text"
            label: "Fixed-width font"
            description: "System-wide monospace: code, terminals that use the default, and the shell's data labels."
            placeholder: "JetBrainsMono Nerd Font"
            def: "JetBrainsMono Nerd Font"
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
        }
    }

    readonly property bool qt: settings.v["apps.qt"] === true
    readonly property string sans: (settings.v["apps.font"] ?? "").trim() || "Noto Sans"
    readonly property string mono: (settings.v["apps.fixedFont"] ?? "").trim() || "JetBrainsMono Nerd Font"
    readonly property int fontSize: settings.v["apps.fontSize"]

    readonly property string envText: "# Written by the shell (plugins/apps/AppTheming.qml); edits here are overwritten.\n" + (qt ? "[environment]\nQT_QPA_PLATFORMTHEME = \"kde\"\n" : "# Qt apps don't follow the theme (Settings: Theme).\n")
    readonly property string appsTheme: qt ? "kde" : ""

    // kdeglobals: what KDE's platform theme reads besides the colours.
    function font(family: string): string {
        return `${family},${settings.v["apps.fontSize"]},-1,5,400,0,0,0,0,0,0,0,0,0,0,1`;
    }
    readonly property var kdeKeys: [
        ["KDE", "widgetStyle", settings.v["apps.style"]],
        ["KDE", "SingleClick", settings.v["apps.singleClick"] === true ? "true" : "false"],
        ["KDE", "ShowIconsInMenuItems", "true"],
        ["Icons", "Theme", settings.v["apps.iconTheme"]],
        ["General", "font", font(root.sans)],
        ["General", "menuFont", font(root.sans)],
        ["General", "toolBarFont", font(root.sans)],
        ["General", "fixed", font(root.mono)]
    ]
    readonly property string kdeText: JSON.stringify(kdeKeys)
    property string kdeWritten: ""

    function applyKde(): void {
        if (!Settings.loaded || !qt || kdeText === kdeWritten)
            return;
        kdeWritten = kdeText;
        const script = 'while [ $# -ge 3 ]; do kwriteconfig6 --file kdeglobals --group "$1" --key "$2" "$3"; shift 3; done; gdbus emit --session --object-path /KGlobalSettings --signal org.kde.KGlobalSettings.notifyChange 0 0 >/dev/null 2>&1';
        Quickshell.execDetached(["sh", "-c", script, "sh"].concat(...kdeKeys));
    }

    // The rest of the system: GTK (its interface settings, which the GTK
    // portal also hands sandboxed apps) and fontconfig's generic families,
    // which browsers, Electron apps and anything asking for "sans-serif" or
    // "monospace" get.
    readonly property string fontconfigText: `<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<!-- Written by the shell (plugins/apps/AppTheming.qml); edits here are overwritten. -->
<fontconfig>
  <alias binding="strong"><family>sans-serif</family><prefer><family>${sans}</family></prefer></alias>
  <alias binding="strong"><family>Sans Serif</family><prefer><family>${sans}</family></prefer></alias>
  <alias binding="strong"><family>monospace</family><prefer><family>${mono}</family></prefer></alias>
  <alias binding="strong"><family>Monospace</family><prefer><family>${mono}</family></prefer></alias>
</fontconfig>
`
    readonly property string gtkFonts: JSON.stringify([sans, mono, fontSize])
    property string gtkWritten: ""
    onFontconfigTextChanged: write(fontconfigFile, fontconfigText)
    onGtkFontsChanged: applyGtkFonts()
    function applyGtkFonts(): void {
        if (!Settings.loaded || gtkFonts === gtkWritten)
            return;
        gtkWritten = gtkFonts;
        Quickshell.execDetached(["sh", "-c", 'gsettings set org.gnome.desktop.interface font-name "$1 $3"; gsettings set org.gnome.desktop.interface document-font-name "$1 $3"; gsettings set org.gnome.desktop.interface monospace-font-name "$2 $3"', "sh", sans, mono, String(fontSize)]);
    }

    // Apps D-Bus and systemd start from now on.
    function applyEnv(): void {
        if (!Settings.loaded)
            return;
        Quickshell.execDetached(["sh", "-c", appsTheme ? 'dbus-update-activation-environment --systemd QT_QPA_PLATFORMTHEME="$1"' : "systemctl --user unset-environment QT_QPA_PLATFORMTHEME", "sh", appsTheme]);
    }
    Component.onCompleted: {
        applyEnv();
        applyKde();
        applyGtkFonts();
    }
    onAppsThemeChanged: applyEnv()
    onKdeTextChanged: applyKde()
    onQtChanged: applyKde()
    readonly property string qtengineText: JSON.stringify({
        theme: {
            colorScheme: scheme,
            iconTheme: settings.v["apps.iconTheme"],
            style: settings.v["apps.style"],
            font: {
                family: root.sans,
                size: settings.v["apps.fontSize"],
                weight: -1
            },
            fontFixed: {
                family: root.mono,
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
            root.applyEnv();
            root.applyKde();
            root.applyGtkFonts();
            root.write(fontconfigFile, root.fontconfigText);
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
        id: fontconfigFile

        property string current: ""
        property bool ready: false

        path: root.home + "/.config/fontconfig/conf.d/60-nafeel-fonts.conf"
        printErrors: false
        onLoaded: {
            current = text();
            ready = true;
            root.write(fontconfigFile, root.fontconfigText);
        }
        onLoadFailed: {
            ready = true;
            Quickshell.execDetached(["mkdir", "-p", root.home + "/.config/fontconfig/conf.d"]);
            root.write(fontconfigFile, root.fontconfigText);
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
