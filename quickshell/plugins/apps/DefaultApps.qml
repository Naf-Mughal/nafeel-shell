// Default apps, as the file-manager plugin did: one file manager for Mod+E,
// for opening folders (xdg-mime inode/directory) and for "Show in folder"
// (the org.freedesktop.FileManager1 D-Bus name: a user service file, which
// wins over the system ones; a different holder is stopped so the new one
// takes the name). The shell writes
//
//   ~/.config/umbriel/plugins/file-manager.toml  Mod+E (included from
//       umbriel's config, whose own keybinds win)
//   ~/.local/share/dbus-1/services/org.freedesktop.FileManager1.service
//
// from the Settings panel's Default apps page. Only installed file managers
// are offered.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

Scope {
    id: root

    readonly property string home: Quickshell.env("HOME")

    // How each known file manager starts: what Mod+E runs, its desktop file,
    // how D-Bus starts it as FileManager1, the process holding that name.
    readonly property var known: ({
            dolphin: {
                label: "Dolphin",
                command: "dolphin",
                desktop: "org.kde.dolphin.desktop",
                dbus: "/usr/bin/dolphin --daemon",
                process: "dolphin"
            },
            thunar: {
                label: "Thunar",
                command: "thunar",
                desktop: "thunar.desktop",
                dbus: "/usr/bin/Thunar --gapplication-service",
                process: "thunar"
            },
            nemo: {
                label: "Nemo",
                command: "nemo",
                desktop: "nemo.desktop",
                dbus: "/usr/bin/nemo --no-default-window",
                process: "nemo"
            },
            nautilus: {
                label: "Files (Nautilus)",
                command: "nautilus",
                desktop: "org.gnome.Nautilus.desktop",
                dbus: "/usr/bin/nautilus --gapplication-service",
                process: "nautilus"
            }
        })
    // The installed ones: [{ value, icon, label }].
    property var installed: []

    readonly property SettingsPage settings: SettingsPage {
        name: "apps"
        title: "Default apps"
        gloss: "应用"
        icon: "apps"
        order: 40
        description: "Which app opens what."

        SettingItem {
            key: "apps.fileManager"
            label: "File manager"
            description: "Mod+E, opening folders, and \"Show in folder\" from screenshots, browsers and others."
            def: "dolphin"
            options: root.installed
        }
    }

    readonly property var app: known[settings.v["apps.fileManager"]] ?? null

    readonly property string bindText: app ? `# Written by the shell (plugins/apps/DefaultApps.qml); edits here are overwritten.
# Included from ~/.config/umbriel/config.toml, whose own [keybinds] win over
# these, so don't bind the same keys there.
[keybinds]
"Mod+E" = { action = "spawn:${app.command}", repeat = false }
` : ""
    readonly property string dbusText: app ? `# Written by the shell (plugins/apps/DefaultApps.qml); edits here are overwritten.
[D-BUS Service]
Name=org.freedesktop.FileManager1
Exec=${app.dbus}
` : ""

    onAppChanged: apply()

    function apply(): void {
        if (!Settings.loaded || !app || !bindFile.ready || !dbusFile.ready)
            return;
        if (bindFile.current !== bindText) {
            bindFile.setText(bindText);
            bindFile.current = bindText;
        }
        if (dbusFile.current !== dbusText) {
            dbusFile.setText(dbusText);
            dbusFile.current = dbusText;
        }
        // Folders open in it; and whoever holds FileManager1, if it isn't
        // this one, makes way (D-Bus starts ours on the next request).
        Quickshell.execDetached(["sh", "-c", '[ "$(xdg-mime query default inode/directory)" = "$1" ] || xdg-mime default "$1" inode/directory; pid=$(busctl --user status org.freedesktop.FileManager1 2>/dev/null | sed -n "s/^PID=//p"); [ -n "$pid" ] || exit 0; [ "$(cat /proc/$pid/comm 2>/dev/null)" = "$2" ] && exit 0; busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus ReloadConfig >/dev/null 2>&1; kill "$pid"', "sh", app.desktop, app.process]);
    }

    Connections {
        target: Settings

        function onLoadedChanged(): void {
            root.apply();
        }
    }

    FileView {
        id: bindFile

        property string current: ""
        property bool ready: false

        path: root.home + "/.config/umbriel/plugins/file-manager.toml"
        printErrors: false
        onLoaded: {
            current = text();
            ready = true;
            root.apply();
        }
        onLoadFailed: {
            ready = true;
            root.apply();
        }
    }

    FileView {
        id: dbusFile

        property string current: ""
        property bool ready: false

        path: root.home + "/.local/share/dbus-1/services/org.freedesktop.FileManager1.service"
        printErrors: false
        onLoaded: {
            current = text();
            ready = true;
            root.apply();
        }
        onLoadFailed: {
            ready = true;
            Quickshell.execDetached(["mkdir", "-p", root.home + "/.local/share/dbus-1/services"]);
            root.apply();
        }
    }

    Process {
        running: true
        command: ["sh", "-c", 'for c in "$@"; do command -v "$c" >/dev/null && echo "$c"; done', "sh"].concat(Object.keys(root.known).map(k => root.known[k].command))
        stdout: StdioCollector {
            onStreamFinished: {
                const have = text.trim().split("\n");
                root.installed = Object.keys(root.known).filter(k => have.includes(root.known[k].command)).map(k => ({
                            value: k,
                            icon: "folder_open",
                            label: root.known[k].label
                        }));
            }
        }
    }
}
