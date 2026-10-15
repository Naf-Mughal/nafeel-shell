import QtQuick
import Quickshell
import Nafeel
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
    // As a texture only (image://still): its decoded copy let go once it's
    // on the GPU (the backdrop and every card's cover at their sizes).
    readonly property url wallpaperStill: Wallpapers.still(wallpaperLive ? Wallpapers.stillOf(wallpaperPath) : wallpaper.toString(), true)
    // The theme sets `source` (the wallpaper) and `run`; the player takes
    // the lock's copy of it (Wallpapers.lockPlayOf).
    readonly property Component liveComponent: Component {
        Item {
            id: lockPlayer

            property url source
            property bool run: true
            signal firstFrame
            signal frame

            readonly property string file: {
                const s = lockPlayer.source.toString();
                return s ? "file://" + Wallpapers.lockPlayOf(s.startsWith("file://") ? s.slice(7) : s) : "";
            }
            property bool fellBack: false

            // The GPU's frames as textures, at the half resolution the theme
            // paints the wallpaper at (no libmpv: ~40 MB of memory and ~75
            // MB of video memory less); libmpv only if that can't run here.
            SceneVideo {
                anchors.fill: parent
                visible: !lockPlayer.fellBack
                resolution: 0.5
                source: lockPlayer.fellBack ? "" : lockPlayer.file
                playing: lockPlayer.run
                onFirstFrame: lockPlayer.firstFrame()
                onFrame: lockPlayer.frame()
                onBroken: {
                    console.warn("lock: the in-scene video engine can't run here; libmpv instead");
                    lockPlayer.fellBack = true;
                }
            }

            Loader {
                anchors.fill: parent
                active: lockPlayer.fellBack
                sourceComponent: VideoLayer {
                    source: lockPlayer.file
                    run: lockPlayer.run
                    onFirstFrame: lockPlayer.firstFrame()
                    onFrame: lockPlayer.frame()
                }
            }
        }
    }

    // A capture the theme draws from that mustn't draw frames of its own
    // (Nafeel's QuietSource): the backdrop's, which redrew the lock twice
    // for every step of its motion.
    function quiet(item: Item): void {
        QuietSource.quiet(item);
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
