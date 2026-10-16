// Default apps, as the file-manager plugin did: one file manager for Mod+E,
// for opening folders (xdg-mime inode/directory) and for "Show in folder"
// (the org.freedesktop.FileManager1 D-Bus name: a user service file, which
// wins over the system ones; a different holder is stopped so the new one
// takes the name). The shell writes
//
//   ~/.config/umbriel/plugins/file-manager.toml  Mod+E (included from
//       umbriel's config, whose own keybinds win)
//   ~/.local/share/dbus-1/services/org.freedesktop.FileManager1.service
//   ~/.config/xdg-desktop-portal/umbriel-portals.conf  the file picker apps
//       open through the portal (VS Code's Open Folder, a browser's upload,
//       save dialogs): Dolphin's (the KDE portal) with Dolphin, else GTK's
//   ~/.config/systemd/user/plasma-xdg-desktop-portal-kde.service.d/nafeel.conf
//       the KDE portal on KDE's platform theme: under qtengine its folder
//       picker (a QFileDialog) fell back to Qt's bare widget dialog; colours
//       still follow the theme (kdeglobals)
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
                process: "dolphin",
                portal: "kde"
            },
            thunar: {
                label: "Thunar",
                command: "thunar",
                desktop: "thunar.desktop",
                dbus: "/usr/bin/Thunar --gapplication-service",
                process: "thunar",
                portal: "gtk"
            },
            nemo: {
                label: "Nemo",
                command: "nemo",
                desktop: "nemo.desktop",
                dbus: "/usr/bin/nemo --no-default-window",
                process: "nemo",
                portal: "gtk"
            },
            nautilus: {
                label: "Files (Nautilus)",
                command: "nautilus",
                desktop: "org.gnome.Nautilus.desktop",
                dbus: "/usr/bin/nautilus --gapplication-service",
                process: "nautilus",
                portal: "gtk"
            }
        })
    // The installed ones: [{ value, icon, label }].
    property var installed: []
    // The KDE portal (xdg-desktop-portal-kde) is installed.
    property bool kdePortal: false

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

    readonly property string chooser: app?.portal === "kde" && kdePortal ? "kde" : "gtk"
    readonly property string portalText: `# Written by the shell (plugins/apps/DefaultApps.qml); edits here are overwritten.
[preferred]
default=umbriel;gtk
org.freedesktop.impl.portal.FileChooser=${chooser}
`

    readonly property string kdeDropIn: `# Written by the shell (plugins/apps/DefaultApps.qml); edits here are overwritten.
[Service]
Environment=QT_QPA_PLATFORMTHEME=kde
`

    onAppChanged: apply()
    onChooserChanged: apply()

    function apply(): void {
        if (!Settings.loaded || !app || !bindFile.ready || !dbusFile.ready || !portalFile.ready || !dropInFile.ready || !probed)
            return;
        if (bindFile.current !== bindText) {
            bindFile.setText(bindText);
            bindFile.current = bindText;
        }
        if (dbusFile.current !== dbusText) {
            dbusFile.setText(dbusText);
            dbusFile.current = dbusText;
        }
        // The portal reads its config at start only.
        if (portalFile.current !== portalText) {
            portalFile.setText(portalText);
            portalFile.current = portalText;
            Quickshell.execDetached(["systemctl", "--user", "try-restart", "xdg-desktop-portal.service"]);
        }
        if (kdePortal && dropInFile.current !== kdeDropIn) {
            dropInFile.setText(kdeDropIn);
            dropInFile.current = kdeDropIn;
            Quickshell.execDetached(["sh", "-c", "systemctl --user daemon-reload && systemctl --user try-restart plasma-xdg-desktop-portal-kde.service"]);
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

    FileView {
        id: portalFile

        property string current: ""
        property bool ready: false

        path: root.home + "/.config/xdg-desktop-portal/umbriel-portals.conf"
        printErrors: false
        onLoaded: {
            current = text();
            ready = true;
            root.apply();
        }
        onLoadFailed: {
            ready = true;
            Quickshell.execDetached(["mkdir", "-p", root.home + "/.config/xdg-desktop-portal"]);
            root.apply();
        }
    }

    FileView {
        id: dropInFile

        property string current: ""
        property bool ready: false

        path: root.home + "/.config/systemd/user/plasma-xdg-desktop-portal-kde.service.d/nafeel.conf"
        printErrors: false
        onLoaded: {
            current = text();
            ready = true;
            root.apply();
        }
        onLoadFailed: {
            ready = true;
            Quickshell.execDetached(["mkdir", "-p", root.home + "/.config/systemd/user/plasma-xdg-desktop-portal-kde.service.d"]);
            root.apply();
        }
    }

    // Wait for the probe below, so the portal isn't set to GTK and back.
    property bool probed: false

    Process {
        running: true
        command: ["sh", "-c", '[ -e /usr/share/xdg-desktop-portal/portals/kde.portal ] && echo kde-portal; for c in "$@"; do command -v "$c" >/dev/null && echo "$c"; done', "sh"].concat(Object.keys(root.known).map(k => root.known[k].command))
        stdout: StdioCollector {
            onStreamFinished: {
                const have = text.trim().split("\n");
                root.kdePortal = have.includes("kde-portal");
                root.installed = Object.keys(root.known).filter(k => have.includes(root.known[k].command)).map(k => ({
                            value: k,
                            icon: "folder_open",
                            label: root.known[k].label
                        }));
                root.probed = true;
                root.apply();
            }
        }
    }
}
