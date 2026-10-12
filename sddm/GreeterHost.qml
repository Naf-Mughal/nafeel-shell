import QtQuick
import "modules/background"

// The login screen's host for the cave-abode surface: the same shape as the
// shell's ShellLockHost, filled from what the shell exports for the greeter
// (`data`: its GreeterData.qml: palette, type, rounding, wallpaper, avatar,
// cultivation, time format; see the shell's services/GreeterExport). Things
// only a running session has (battery, media, capture) are absent.
QtObject {
    id: root

    // The exported data (null until loaded) and the folder it's in.
    property var data: null
    property string dir: ""

    function file(name: string): url {
        return name ? "file://" + dir + "/" + name : "";
    }

    readonly property string fontCjk: data?.fontCjk ?? "Noto Serif CJK SC"
    readonly property string fontSerif: data?.fontSerif ?? "Noto Serif"
    readonly property real radiusSmall: data?.radiusSmall ?? 8
    readonly property real radiusNormal: data?.radiusNormal ?? 10

    readonly property bool follow: data?.follow ?? false
    readonly property var m3: data?.m3 ?? ({})

    // A live wallpaper plays here too (the shell's own player, VideoLayer),
    // its first frame showing until it starts.
    readonly property bool wallpaperLive: data?.wallpaperLive ?? false
    readonly property url wallpaper: file(data?.wallpaper ?? "")
    readonly property url wallpaperStill: file(data?.wallpaperStill ?? data?.wallpaper ?? "")
    readonly property Component liveComponent: Component {
        VideoLayer {}
    }
    readonly property url avatar: file(data?.avatar ?? "")

    readonly property QtObject battery: QtObject {
        readonly property bool present: false
        readonly property real level: 0
        readonly property bool charging: false
        readonly property bool low: false
    }

    // The shell's cultivation, as of the last export (the same formulas as
    // its LockStats).
    readonly property QtObject stats: QtObject {
        readonly property real xp: root.data?.xp ?? 0
        readonly property int streak: root.data?.streak ?? 0
        readonly property int achieved: root.data?.achieved ?? 0
        readonly property int achievable: root.data?.achievable ?? 0

        function levelFor(xp: real): int {
            return Math.max(1, Math.floor((1 + Math.sqrt(1 + 0.08 * Math.max(0, xp))) / 2));
        }

        function xpForLevel(level: int): int {
            return 50 * level * (level - 1);
        }
    }

    readonly property QtObject media: QtObject {
        readonly property bool active: false
        readonly property bool playing: false
        readonly property string title: ""
        readonly property string artist: ""

        function call(action: string): void {
        }
    }

    readonly property QtObject capture: QtObject {
        readonly property bool available: false
        readonly property bool recording: false
        readonly property bool paused: false

        function command(event: string): void {
        }

        function recordedSeconds(now: date): int {
            return 0;
        }
    }
}
