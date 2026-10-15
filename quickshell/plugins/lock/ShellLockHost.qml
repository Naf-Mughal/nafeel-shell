import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.modules.background

// What the cave-abode surface (themes/xianxia) needs from whoever shows it,
// filled from the shell's services. The SDDM greeter has its own host with
// the same shape (sddm/cave-abode), so the surface files are shared, not
// copied, and import nothing of the shell.
QtObject {
    id: root

    // Type and shape.
    readonly property string fontCjk: Tokens.font.cjk
    readonly property string fontSerif: Tokens.font.serif
    readonly property real radiusSmall: Tokens.rounding.small
    readonly property real radiusNormal: Tokens.rounding.normal
    readonly property real radiusMorph: Tokens.rounding.morph
    readonly property real paperFibre: Tokens.paperTexture
    readonly property real paperInk: Tokens.immersive ? 1 : 0.55
    // A card's paper, as the panels' (frosted: translucent).
    readonly property color paperFill: Qt.alpha(Colours.roleFill("paper", "soft", 2), Tokens.transparency.base)
    // Motion: the theme's timings at the shell's tempo, none when reduced.
    readonly property real motion: Tokens.reduceMotion ? 0 : Tokens.tempo

    // The palette, on the theme's roles; `follow` false keeps the original
    // ink and gold (the Session & lock page, or a light palette).
    readonly property bool follow: CaveAbode.followPalette && !Colours.light
    readonly property var m3: Colours.palette

    // The wallpaper: a picture, or a live one (its still first, then the
    // player `liveComponent`, which takes `source` and `run`).
    readonly property string wallpaperPath: CaveAbode.wallpaperPath
    readonly property url wallpaper: CaveAbode.wallpaper
    readonly property bool wallpaperLive: Wallpapers.isVideo(wallpaperPath)
    readonly property url wallpaperStill: wallpaperLive ? "file://" + Wallpapers.stillOf(wallpaperPath) : wallpaper
    // The theme sets `source` (the wallpaper) and `run`; the player takes
    // the lock's copy of it (Wallpapers.lockPlayOf).
    readonly property Component liveComponent: Component {
        Item {
            id: lockPlayer

            property url source
            property bool run: true
            signal firstFrame

            VideoLayer {
                anchors.fill: parent
                source: {
                    const s = lockPlayer.source.toString();
                    return s ? "file://" + Wallpapers.lockPlayOf(s.startsWith("file://") ? s.slice(7) : s) : "";
                }
                run: lockPlayer.run
                onFirstFrame: lockPlayer.firstFrame()
            }
        }
    }

    readonly property url avatar: CaveAbode.avatar
    // The running session's things on the lock, on the shell's own
    // primitives: what's playing, capture, the OSD, notifications.
    readonly property Component sessionComponent: Component {
        LockSessionLayer {}
    }
    // NAFEEL_LOCK_OFF (parts the theme leaves out, for measuring).
    readonly property string debugOff: Quickshell.env("NAFEEL_LOCK_OFF") ?? ""

    readonly property QtObject battery: QtObject {
        readonly property bool present: Power.hasBattery
        readonly property real level: Power.level
        readonly property bool charging: Power.charging
        readonly property bool low: Power.low
    }

    readonly property QtObject stats: QtObject {
        readonly property real xp: LockStats.xp
        readonly property int streak: LockStats.liveStreak
        readonly property int achieved: LockStats.achievements.length
        readonly property int achievable: LockStats.achievementDefs.length

        function levelFor(xp: real): int {
            return LockStats.levelFor(xp);
        }

        function xpForLevel(level: int): int {
            return LockStats.xpForLevel(level);
        }
    }

    readonly property QtObject media: QtObject {
        readonly property bool active: Media.active !== null
        readonly property bool playing: Media.playing
        readonly property string title: Media.title
        readonly property string artist: Media.artist

        // "playPause" | "previous" | "next"
        function call(action: string): void {
            Media[action]();
        }
    }

    readonly property QtObject capture: QtObject {
        readonly property bool available: CaveAbode.captureAvailable
        readonly property bool recording: CaveAbode.recording
        readonly property bool paused: CaveAbode.recordingPaused

        function command(event: string): void {
            CaveAbode.captureCommand(event);
        }

        function recordedSeconds(now: date): int {
            return CaveAbode.recordedSeconds(now);
        }
    }
}
