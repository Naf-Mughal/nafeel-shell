import QtQuick
import qs.config

// The session entrance's host for the cave-abode surface (Entrance.qml):
// the login screen's own (sddm/GreeterHost.qml), filled from the same
// GreeterData.qml, so the first frames are what SDDM just showed (its
// palette and picture) rather than the shell's defaults, then a jump once
// its settings load. Only the still (no player), no session picker.
QtObject {
    id: root

    // The exported data (GreeterData.qml's object) and the folder it's in.
    property var data: null
    property string dir: ""

    function file(name: string): url {
        return name ? "file://" + dir + "/" + name : "";
    }

    readonly property string fontCjk: data?.fontCjk ?? "Noto Serif CJK SC"
    readonly property string fontSerif: data?.fontSerif ?? "Noto Serif"
    readonly property real radiusSmall: data?.radiusSmall ?? 8
    readonly property real radiusNormal: data?.radiusNormal ?? 10
    readonly property real radiusMorph: data?.radiusMorph ?? 14
    readonly property real paperFibre: data?.paperFibre ?? 0.5
    readonly property real paperInk: data?.paperInk ?? 0.55
    readonly property color paperFill: data?.paperFill ?? Qt.rgba(0.08, 0.09, 0.12, 0.85)
    readonly property real motion: Tokens.reduceMotion ? 0 : Tokens.tempo

    readonly property bool follow: data?.follow ?? false
    readonly property var m3: data?.m3 ?? ({})

    readonly property bool wallpaperLive: false
    readonly property url wallpaper: file(data?.wallpaper ?? "")
    readonly property url wallpaperStill: file(data?.wallpaperStill ?? data?.wallpaper ?? "")
    readonly property Component liveComponent: null
    readonly property url avatar: file(data?.avatar ?? "")
    readonly property Component sessionComponent: null

    readonly property QtObject battery: QtObject {
        readonly property bool present: false
        readonly property real level: 0
        readonly property bool charging: false
        readonly property bool low: false
    }

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
