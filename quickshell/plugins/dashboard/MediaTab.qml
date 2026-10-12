pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.Mpris
import M3Shapes
import Nafeel
import qs.config
import qs.services
import qs.components

// Media (after Caelestia's, on the shell's parts, tightened at the user's
// ask): bongocat drumming in a ring with the music coming off it; the
// track's details, its position and the controls; the lyrics following the
// song, and which player to show. Nothing playing: a clamshell and a line.
Item {
    id: root

    implicitHeight: 280
    readonly property var player: Media.active
    readonly property real length: player?.length ?? 0

    function time(s: real): string {
        if (!(s >= 0))
            return "-:--";
        s = Math.floor(s);
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = String(s % 60).padStart(2, "0");
        return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${sec}` : `${m}:${sec}`;
    }

    Component.onCompleted: Lyrics.watchers++
    Component.onDestruction: Lyrics.watchers--

    // MPRIS only updates the position when asked.
    Timer {
        running: root.visible && Media.playing
        interval: 500
        repeat: true
        triggeredOnStart: true
        onTriggered: root.player?.positionChanged()
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Tokens.spacing.small
        spacing: Tokens.spacing.large

        // ── Bongocat, and the music off the ring round it ──
        Item {
            id: visual

            Layout.preferredWidth: 260
            Layout.fillHeight: true

            readonly property real cx: width / 2
            readonly property real cy: height / 2
            readonly property real reach: (Math.min(width, height) - cover.width) / 2 - 8

            Loader {
                active: Media.playing
                sourceComponent: ServiceRef {
                    service: Visualiser.cava
                }
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                data: bars.instances
            }

            Variants {
                id: bars

                model: Array.from({
                    length: Visualiser.bars
                }, (_, i) => i)

                ShapePath {
                    id: bar

                    required property int modelData
                    readonly property real value: Math.max(0.02, Math.min(1, Visualiser.cava.values[modelData] ?? 0))
                    readonly property real angle: modelData * 2 * Math.PI / Visualiser.bars
                    readonly property real edge: cover.width / 2 + 6
                    readonly property real dist: edge + visual.reach * value

                    strokeWidth: 360 / Visualiser.bars - 2
                    strokeColor: Colours.roleInk("primary", "ghost")
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    startX: visual.cx + Math.cos(angle) * edge
                    startY: visual.cy + Math.sin(angle) * edge

                    PathLine {
                        x: visual.cx + Math.cos(bar.angle) * bar.dist
                        y: visual.cy + Math.sin(bar.angle) * bar.dist
                    }
                }
            }

            // The ring and bongocat in it, drumming while it plays.
            Rectangle {
                id: cover

                anchors.centerIn: parent
                width: 170
                height: 170
                radius: width / 2
                color: Colours.roleFill("paper", "soft", 3)

                AnimatedImage {
                    anchors.fill: parent
                    anchors.margins: 22
                    source: Qt.resolvedUrl("../../assets/bongocat.gif")
                    fillMode: AnimatedImage.PreserveAspectFit
                    playing: Media.playing
                    asynchronous: true
                }
            }
        }

        // ── Nothing playing ──
        Column {
            visible: !root.player
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Tokens.spacing.small

            ShapeBadge {
                anchors.horizontalCenter: parent.horizontalCenter
                implicitSize: 110
                shape: MaterialShape.ClamShell
                role: "primary"
                icon: "queue_music"
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Nothing playing"
                color: Colours.roleInk("paper", "soft")
                font.pixelSize: 26
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Play something for it to show up here."
                color: Colours.roleSubInk("paper", "soft")
                font.pixelSize: Tokens.font.row
            }
        }

        // ── The track: its words centred on the cat, the position and the
        // controls at the foot, level with the player selector ──
        ColumnLayout {
            visible: !!root.player
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4

            Item {
                Layout.fillHeight: true
            }

            StyledText {
                Layout.fillWidth: true
                text: root.player?.trackTitle || "Unknown title"
                color: Colours.roleInk("paper", "soft")
                font.pixelSize: 24
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: root.player?.trackArtist || "Unknown artist"
                color: Colours.roleSubInk("paper", "soft")
                font.pixelSize: Tokens.font.title
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: root.player?.trackAlbum || "Unknown album"
                color: Colours.roleInk("secondary", "ghost")
                font.pixelSize: Tokens.font.title
                elide: Text.ElideRight
            }

            Item {
                Layout.fillHeight: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    text: root.time(root.player?.position ?? -1)
                    color: Colours.roleSubInk("paper", "soft")
                    font.family: Tokens.font.mono
                    font.pixelSize: Tokens.font.small
                }

                StyledSlider {
                    Layout.fillWidth: true
                    implicitHeight: 16
                    to: Math.max(1, root.length)
                    value: root.player?.position ?? 0
                    onMoved: v => {
                        if (root.player?.canSeek)
                            root.player.position = v;
                    }
                }

                StyledText {
                    text: root.time(root.length)
                    color: Colours.roleSubInk("paper", "soft")
                    font.family: Tokens.font.mono
                    font.pixelSize: Tokens.font.small
                }
            }

            // Shuffle · previous · play (wide) · next · repeat: one height,
            // the shell's rounding.
            RowLayout {
                Layout.topMargin: Tokens.spacing.small
                Layout.fillWidth: true
                spacing: 4

                MediaControl {
                    icon: "shuffle"
                    on: root.player?.shuffle ?? false
                    enabled: root.player?.shuffleSupported ?? false
                    onClicked: root.player.shuffle = !root.player.shuffle
                }

                MediaControl {
                    icon: "skip_previous"
                    onClicked: Media.previous()
                }

                MediaControl {
                    Layout.fillWidth: true
                    icon: Media.playing ? "pause" : "play_arrow"
                    iconSize: 26
                    on: Media.playing
                    onClicked: Media.togglePlaying()
                }

                MediaControl {
                    icon: "skip_next"
                    onClicked: Media.next()
                }

                MediaControl {
                    icon: root.player?.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                    on: (root.player?.loopState ?? MprisLoopState.None) !== MprisLoopState.None
                    enabled: root.player?.loopSupported ?? false
                    onClicked: {
                        const st = root.player.loopState;
                        root.player.loopState = st === MprisLoopState.None ? MprisLoopState.Track : st === MprisLoopState.Track ? MprisLoopState.Playlist : MprisLoopState.None;
                    }
                }
            }
        }

        // ── Lyrics, and the player ──
        ColumnLayout {
            visible: !!root.player
            Layout.preferredWidth: 280
            Layout.fillHeight: true
            spacing: Tokens.spacing.small

            Row {
                spacing: Tokens.spacing.small

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "lyrics"
                    size: 22
                    color: Colours.roleInk("paper", "soft")
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Lyrics"
                    color: Colours.roleInk("paper", "soft")
                    font.pixelSize: Tokens.font.title
                }

                MicroLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Lyrics.state === "loading" ? "· finding them" : Lyrics.lines.length ? "· lrclib" : ""
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: lines

                    anchors.fill: parent
                    visible: Lyrics.lines.length > 0
                    clip: true
                    model: Lyrics.lines
                    spacing: 6
                    interactive: false
                    currentIndex: Math.max(0, Lyrics.current)
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    preferredHighlightBegin: height / 2 - 16
                    preferredHighlightEnd: height / 2 + 16
                    highlightMoveDuration: Tokens.dur(420)

                    delegate: StyledText {
                        required property var modelData
                        required property int index
                        readonly property bool now: index === Lyrics.current

                        width: lines.width
                        wrapMode: Text.WordWrap
                        text: modelData.text || "♪"
                        color: now ? Colours.roleInk("primary", "ghost") : Colours.roleSubInk("paper", "soft")
                        opacity: now ? 1 : Math.max(0.3, 0.8 - Math.abs(index - Lyrics.current) * 0.12)
                        font.pixelSize: now ? Tokens.font.title : Tokens.font.row
                        font.weight: now ? Font.DemiBold : Font.Normal
                    }
                }

                Scroller {
                    anchors.fill: parent
                    visible: Lyrics.lines.length === 0 && Lyrics.plain !== ""
                    contentHeight: plainText.implicitHeight
                    clip: true

                    StyledText {
                        id: plainText

                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: Lyrics.plain
                        color: Colours.roleSubInk("paper", "soft")
                        font.pixelSize: Tokens.font.row
                    }
                }

                Column {
                    anchors.centerIn: parent
                    visible: Lyrics.state === "none" || Lyrics.state === "idle"
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "sentiment_dissatisfied"
                        size: 44
                        color: Colours.roleSubInk("paper", "soft")
                    }

                    StyledText {
                        text: "No lyrics found"
                        color: Colours.roleSubInk("paper", "soft")
                        font.pixelSize: Tokens.font.row
                    }
                }
            }

            // Which player: full width at the foot.
            PlayerSelect {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
            }
        }
    }
}
