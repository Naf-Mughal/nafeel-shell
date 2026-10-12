pragma Singleton

// What the login screen (the SDDM theme in sddm/: the shell's own lock
// surface) shows, exported from the shell so it's the same world: its
// palette and whether the lock follows it, the type and rounding, the time
// format, the cultivation, the user, a copy of the wallpaper (a live one's
// still) and the avatar. Written as GreeterData.qml (a QtObject the theme
// loads) into ~/.local/state/nafeel-shell/greeter, and into
// /var/lib/nafeel-greeter when it's there and ours (bin/nafeel-greeter
// install creates it: the greeter's user can't read the home folder).
// Rewritten a moment after anything in it changes.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.config

Singleton {
    id: root

    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/nafeel-shell/greeter"
    readonly property string systemDir: "/var/lib/nafeel-greeter"

    // The palette roles the surface uses (and the rest, for later themes).
    readonly property var roles: ["m3background", "m3error", "m3errorContainer", "m3onBackground", "m3onError", "m3onPrimary", "m3onPrimaryContainer", "m3onSecondary", "m3onSecondaryContainer", "m3onSurface", "m3onSurfaceVariant", "m3onTertiary", "m3onTertiaryContainer", "m3outline", "m3outlineVariant", "m3primary", "m3primaryContainer", "m3primaryFixed", "m3primaryFixedDim", "m3secondary", "m3secondaryContainer", "m3surface", "m3surfaceBright", "m3surfaceContainer", "m3surfaceContainerHigh", "m3surfaceContainerHighest", "m3surfaceContainerLow", "m3surfaceContainerLowest", "m3surfaceDim", "m3surfaceVariant", "m3tertiary", "m3tertiaryContainer"]

    // The wallpaper: a picture as it is; a live one as the video the shell
    // plays (playOf: the resolution setting's copy) and a full-size first
    // frame (made with ffmpeg) for the moment before it starts.
    readonly property bool live: Wallpapers.isVideo(Wallpapers.current)
    readonly property string wallpaperPath: live ? Wallpapers.playOf(Wallpapers.current) : Wallpapers.current
    readonly property string wallpaperName: wallpaperPath ? "wallpaper" + (wallpaperPath.match(/\.[A-Za-z0-9]+$/)?.[0] ?? "") : ""

    readonly property var data: {
        const m3 = {};
        for (const r of roles)
            m3[r] = Colours.palette[r].toString();
        return {
            userName: Session.user,
            realName: Session.realName,
            follow: CaveAbode.followPalette && !Colours.light,
            m3: m3,
            fontCjk: Tokens.font.cjk,
            fontSerif: Tokens.font.serif,
            radiusSmall: Tokens.rounding.small,
            radiusNormal: Tokens.rounding.normal,
            h24: Time.h24,
            xp: LockStats.xp,
            streak: LockStats.liveStreak,
            achieved: LockStats.achievements.length,
            achievable: LockStats.achievementDefs.length,
            wallpaper: wallpaperName,
            wallpaperLive: live,
            wallpaperStill: live ? "wallpaper-still.jpg" : wallpaperName,
            avatar: "avatar"
        };
    }

    // (An object goes in parentheses, or QML reads it as a block.)
    readonly property string text: "// Written by the nafeel shell (plugins/lock/GreeterExport.qml) for the login\n// screen; edits here are overwritten.\nimport QtQuick\n\nQtObject {\n" + Object.keys(data).map(k => `    property var ${k}: (${JSON.stringify(data[k])})`).join("\n") + "\n}\n"

    onTextChanged: later.restart()
    onWallpaperPathChanged: later.restart()

    Timer {
        id: later

        interval: 2000
        onTriggered: root.write()
    }

    function write(): void {
        if (!LockStats.ready || !Wallpapers.current)
            return;
        // Into the state folder, then the system one when it's ours; each
        // file lands whole (written, then renamed).
        writer.command = ["sh", "-c", `
put() {
  d="$1"
  mkdir -p "$d" 2>/dev/null && [ -w "$d" ] || return 0
  printf '%s' "$2" > "$d/GreeterData.qml.tmp" && mv -f "$d/GreeterData.qml.tmp" "$d/GreeterData.qml"
  if [ -n "$3" ] && [ -f "$3" ]; then
    if ! cmp -s "$3" "$d/$4"; then
      rm -f "$d"/wallpaper.* "$d/wallpaper-still.jpg"
      cp -f "$3" "$d/$4.tmp" && mv -f "$d/$4.tmp" "$d/$4"
    fi
    if [ "$7" = true ] && [ ! -f "$d/wallpaper-still.jpg" ]; then
      ffmpeg -y -loglevel error -i "$d/$4" -frames:v 1 -q:v 3 "$d/wallpaper-still.jpg" </dev/null || true
    fi
  fi
  if [ -f "$HOME/.face" ]; then cmp -s "$HOME/.face" "$d/avatar" || cp -f "$HOME/.face" "$d/avatar"; else rm -f "$d/avatar"; fi
  chmod -R a+rX "$d" 2>/dev/null
}
put "$5" "$2" "$3" "$4" "" "" "$7"
[ -d "$6" ] && put "$6" "$2" "$3" "$4" "" "" "$7"
exit 0`, "sh", "", root.text, root.wallpaperPath, root.wallpaperName, root.stateDir, root.systemDir, String(root.live)];
        writer.running = true;
    }

    Process {
        id: writer
    }

    Component.onCompleted: later.restart()
}
