pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../.."

// "Sealed Cave Abode" theme: a cultivator sealing their cave for
// closed-door cultivation.
//
// Lock-in: a golden formation draws itself over the desktop, a cinnabar 封
// seal slams down, and the desktop dissolves into ink, revealing the
// wallpaper redrawn as a moonlit ink painting with drifting mist and qi motes.
// Typing lights the formation's runes; a wrong password is a qi deviation
// (走火入魔) that burns an incense stick (lives); a lockout is closed-door
// seclusion. Unlocking stamps 开, raises a pillar of light, shows cultivation
// gained (and a 突破 breakthrough when the realm advances), then the formation
// bursts and the ink recedes from the centre back into the desktop.
//
// Theme contract: ctx (the lock's state: LockContext in the shell, the
// greeter's context in SDDM), host (what the surface needs from where it
// runs: ShellLockHost, or the greeter's), shot, shown, still, minScale.
// Nothing here imports the shell, so the SDDM theme shares these files.
Item {
    id: xian
    // NAFEEL_LOCK_OFF=backdrop,hud,formation,wall: leave parts out, to
    // measure what each costs a frame (bin/frame-probe's lock runs).
    // (From the host: the shell's reads the environment; the greeter's has none.)
    readonly property var debugOff: String(xian.host?.debugOff ?? "").split(",")

    required property var ctx
    required property var host

    // Xian reads the palette and type from the host (set as soon as it's
    // given, before anything draws).
    onHostChanged: Xian.host = host
    property url shot
    property bool shown: true
    property bool still: false
    property real minScale: 0.7
    // Compact (the polkit prompt): the lock as it is (the desktop soaking
    // into ink, the backdrop, formation, prompt, seals and choreography)
    // without the title, hour, cultivator, music, tokens or insights. Esc
    // leaves (ctx.leave()).
    property bool compact: false
    // The prompt's idle line (compact: what's asking).
    property string idleLine: "Recite the incantation to break the seal"

    readonly property real sc: Math.max(minScale, Math.min(2, Math.min(width / 1920, height / 1080)))
    readonly property real edge: 60 * sc
    readonly property real formationY: height * 0.42

    // Choreography.
    property real draw: 0
    property real dissolve: 0
    property real wash: 0
    property bool inward: false
    property real uiIn: 0
    property real sealIn: 0
    property real sealOut: 0
    property real openIn: 0
    property real pillar: 0
    property real alarm: 0
    property real surge: 0
    property real burst: 0
    property real deviation: 0
    property real breakthrough: 0
    property real rewardIn: 0
    property real shakeX: 0
    property real shakeY: 0
    property real spin: 0
    property real _lastAmbient: 0

    // Cultivation shown on the card: follows the stored XP, but runs up
    // from the old value during the reward (a crossing is a breakthrough).
    property real shownXp: xian.host.stats.xp
    readonly property int shownLevel: xian.host.stats.levelFor(shownXp)
    readonly property var realm: Xian.realm(shownLevel)
    readonly property int levelFloor: xian.host.stats.xpForLevel(shownLevel)
    readonly property int levelCeil: xian.host.stats.xpForLevel(shownLevel + 1)
    property bool rewarding: false
    property int _seenLevel: 0

    readonly property bool granted: ctx.phase === "granted" || ctx.phase === "exiting"
    readonly property var reward: ctx.reward

    Component.onCompleted: {
        _seenLevel = shownLevel;
        if (still) {
            draw = 1;
            dissolve = 1;
            uiIn = 1;
            sealOut = 1;
        } else if (shown) {
            startIntro();
        } else {
            introFallback.start();
        }
    }

    onShownLevelChanged: {
        if (rewarding && _seenLevel > 0 && shownLevel > _seenLevel)
            breakthroughFx.restart();
        _seenLevel = shownLevel;
    }

    onShownChanged: if (shown && !still) startIntro()

    property bool _introStarted: false

    function startIntro() {
        if (_introStarted)
            return;
        _introStarted = true;
        introFallback.stop();
        intro.start();
    }

    Timer {
        id: introFallback
        interval: 500
        onTriggered: xian.startIntro()
    }

    Connections {
        target: xian.ctx

        function onAmbientTimeChanged() {
            const t = xian.ctx.ambientTime;
            const dt = Math.max(0, Math.min(0.1, t - xian._lastAmbient));
            xian._lastAmbient = t;
            xian.spin += dt * (xian.ctx.phase === "verifying" ? 75 : 7);
        }

        function onPhaseChanged() {
            if (xian.ctx.phase === "exiting") {
                intro.stop();
                outro.start();
            }
        }

        function onDenied(costLife) {
            deviationFx.restart();
        }

        function onGranted() {
            if (xian.reward) {
                xian.rewarding = true;
                xian.shownXp = xian.reward.xpBefore;
                qiFill.restart();
            }
            grantFx.restart();
        }
    }

    // ── The ink world ────────────────────────────────────────────────
    // Compact: the ink is translucent, the desktop (live, the windows as
    // they are) under it, and no painted backdrop.
    Rectangle {
        anchors.fill: parent
        color: xian.compact ? Xian.alpha(Xian.ink, 0.62) : Xian.ink
    }

    Item {
        visible: !xian.compact
        width: 0
        height: 0
        clip: true

        // The wallpaper, picture or live (the background lets go of a live
        // one while locked, so this is the only player), as a texture for
        // the ink painting below.
        Item {
            id: wallItem

            readonly property bool live: xian.host.wallpaperLive
            property bool liveReady: false
            readonly property bool ready: live ? (liveReady || wallpaper.status === Image.Ready) : wallpaper.status === Image.Ready

            width: xian.width
            height: xian.height

            Image {
                id: wallpaper
                anchors.fill: parent
                // A live wallpaper's still until its first frames.
                source: xian.host.wallpaperStill
                sourceSize: Qt.size(Math.max(1, xian.width), Math.max(1, xian.height))
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
            }

            Loader {
                anchors.fill: parent
                active: wallItem.live && xian.host.liveComponent !== null
                sourceComponent: xian.host.liveComponent
                // The host's player: the live file, playing until the screen
                // dims (as the rest of the motion).
                onLoaded: {
                    item.source = Qt.binding(() => xian.host.wallpaper);
                    item.run = Qt.binding(() => xian.ctx.awake);
                    item.firstFrame.connect(() => wallItem.liveReady = true);
                }
            }
        }

        // The wallpaper at half resolution: the downscale is the backdrop's
        // softening (one tap, not nine), and the capture costs a quarter.
        ShaderEffectSource {
            id: wallTex
            sourceItem: wallItem
            live: true
            hideSource: true
            textureSize: Qt.size(Math.max(1, Math.round(xian.width / 2)), Math.max(1, Math.round(xian.height / 2)))
            smooth: true
        }

        // The mist banks at a quarter of the screen each way, smooth under
        // bilinear filtering: low-frequency and slow, they were most of the
        // backdrop's cost worked out per screen pixel.
        ShaderEffect {
            id: mistField

            width: Math.max(1, Math.round(xian.width / 4))
            height: Math.max(1, Math.round(xian.height / 4))
            property real time: xian.ctx.ambientTime

            fragmentShader: Qt.resolvedUrl("../../../../shaders/lock_ink_mist.frag.qsb")
        }

        ShaderEffectSource {
            id: mistTex
            sourceItem: mistField
            live: true
            hideSource: true
            smooth: true
        }
    }

    ShaderEffect {
        anchors.fill: parent
        visible: wallItem.ready && !xian.compact && !xian.debugOff.includes("backdrop")

        property variant wall: wallTex
        property variant mist: mistTex
        property real itemWidth: width
        property real itemHeight: height
        property real time: xian.ctx.ambientTime
        property real motes: 1
        property color inkColor: Xian.ink
        property color mistColor: Xian.mist
        property color goldColor: Xian.gold

        fragmentShader: Qt.resolvedUrl("../../../../shaders/lock_ink_backdrop.frag.qsb")
    }

    LockInput {
        ctx: xian.ctx
        active: !xian.still
        onEscapePressed: xian.compact ? xian.ctx.leave() : xian.ctx.clearInput()
    }

    // ── The desktop, dissolving into ink (under the formation) ───────
    CaptureImage {
        id: capture
        source: xian.shot
        imageWidth: xian.width
        imageHeight: xian.height
    }

    ShaderEffect {
        anchors.fill: parent
        visible: capture.ready && xian.dissolve < 1

        property variant source: capture.image
        property real itemWidth: width
        property real itemHeight: height
        property real progress: xian.dissolve
        property real desat: xian.wash
        property real inward: xian.inward ? 1 : 0
        property point origin: Qt.point(0.5, xian.formationY / Math.max(1, xian.height))
        property color inkColor: Xian.ink
        property color goldColor: Xian.gold

        fragmentShader: Qt.resolvedUrl("../../../../shaders/lock_ink_dissolve.frag.qsb")
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        visible: !capture.ready && opacity > 0
        opacity: 1 - xian.dissolve
    }

    // ── HUD ──────────────────────────────────────────────────────────
    Item {
        id: hud
        anchors.fill: parent
        visible: !xian.debugOff.includes("hud")
        transform: Translate {
            x: xian.shakeX
            y: xian.shakeY
        }

        // A pillar of light for the breakthrough, behind the formation.
        Rectangle {
            x: (parent.width - width) / 2
            y: 0
            width: 170 * xian.sc * (0.55 + 0.45 * xian.pillar)
            height: parent.height
            opacity: xian.pillar
            visible: opacity > 0
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.3; color: Xian.alpha(Xian.gold, 0.35) }
                GradientStop { position: 0.5; color: Xian.alpha(Xian.goldHi, 0.9) }
                GradientStop { position: 0.7; color: Xian.alpha(Xian.gold, 0.35) }
                GradientStop { position: 1; color: "transparent" }
            }
        }

        Formation {
            id: formation
            visible: !xian.debugOff.includes("formation")
            anchors.horizontalCenter: parent.horizontalCenter
            y: xian.formationY - height / 2
            ctx: xian.ctx
            sc: xian.sc
            draw: xian.draw
            spin: xian.spin
            alarm: xian.alarm
            surge: xian.surge
            hush: Math.max(xian.deviation, Math.min(1, xian.breakthrough), xian.openIn, xian.sealIn * (1 - xian.sealOut))
            scale: 1 + 0.35 * xian.burst
            opacity: 1 - xian.burst
        }

        // Title, top left: 洞府封印 in a vertical column.
        Row {
            visible: !xian.compact
            x: xian.edge
            y: 44 * xian.sc
            spacing: 16 * xian.sc
            // Quickly: the calligraphy writes itself in.
            opacity: Math.min(1, xian.uiIn * 3)

            Calligraphy {
                text: "洞府封印"
                sc: xian.sc
                go: xian.uiIn > 0.05
                color: Xian.paper
            }

            Rectangle {
                width: 1 * xian.sc
                height: 142 * xian.sc
                color: Xian.alpha(Xian.gold, 0.5)
            }

            Column {
                spacing: 6 * xian.sc

                Text {
                    text: "SEALED CAVE ABODE"
                    font.family: Xian.serif
                    font.pixelSize: 15 * xian.sc
                    font.letterSpacing: 5 * xian.sc
                    color: Xian.gold
                }

                Text {
                    text: "Closed-door cultivation"
                    font.family: Xian.serif
                    font.italic: true
                    font.pixelSize: 14 * xian.sc
                    color: Xian.paperDim
                }

                Text {
                    readonly property int s: Math.max(0, Math.floor((xian.ctx.now.getTime() - xian.ctx.lockedAt) / 1000))
                    text: Math.floor(s / 3600) + ":" + String(Math.floor(s / 60) % 60).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0")
                    font.family: Xian.serif
                    font.weight: Font.Light
                    font.pixelSize: 24 * xian.sc
                    color: Xian.paper
                }
            }
        }

        // The hour, top right: 时辰 in a vertical column.
        Row {
            visible: !xian.compact
            anchors.right: parent.right
            anchors.rightMargin: xian.edge
            y: 44 * xian.sc
            spacing: 16 * xian.sc
            // Quickly: the calligraphy writes itself in.
            opacity: Math.min(1, xian.uiIn * 3)
            layoutDirection: Qt.RightToLeft

            Calligraphy {
                text: Xian.shichen(xian.ctx.now).zh
                sc: xian.sc
                go: xian.uiIn > 0.05
                color: Xian.gold
            }

            Rectangle {
                width: 1 * xian.sc
                height: 142 * xian.sc
                color: Xian.alpha(Xian.gold, 0.5)
            }

            Column {
                spacing: 6 * xian.sc

                Text {
                    anchors.right: parent.right
                    text: Xian.shichen(xian.ctx.now).en
                    font.family: Xian.serif
                    font.pixelSize: 15 * xian.sc
                    font.letterSpacing: 2 * xian.sc
                    color: Xian.paper
                }

                Text {
                    anchors.right: parent.right
                    text: Xian.chineseDate(xian.ctx.now) + "  ·  " + Qt.formatDate(xian.ctx.now, "dddd")
                    font.family: Xian.cjk
                    font.pixelSize: 14 * xian.sc
                    color: Xian.paperDim
                }

                Text {
                    anchors.right: parent.right
                    visible: xian.host.battery.present
                    text: "灵力 " + Math.round(xian.host.battery.level * 100) + "%" + (xian.host.battery.charging ? " · 聚气" : "")
                    font.family: Xian.cjk
                    font.pixelSize: 14 * xian.sc
                    color: xian.host.battery.low ? Xian.cinnabar : Xian.paperDim
                }

                Text {
                    anchors.right: parent.right
                    visible: xian.ctx.capsLock
                    text: "CAPS LOCK"
                    font.family: Xian.serif
                    font.pixelSize: 13 * xian.sc
                    font.letterSpacing: 3 * xian.sc
                    color: Xian.cinnabar
                }
            }
        }

        // Prompt / reward, under the formation (shared with the polkit prompt).
        SealPrompt {
            id: promptArea
            anchors.horizontalCenter: parent.horizontalCenter
            y: formation.y + formation.height - 6 * xian.sc
            ctx: xian.ctx
            sc: xian.sc
            rewardIn: xian.rewardIn
            idleLine: xian.idleLine
            opacity: xian.uiIn
        }

        // The cultivator, bottom centre (as the dashboard's user card).
        CultivatorCard {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 44 * xian.sc
            visible: !xian.compact
            opacity: xian.uiIn
            xian: xian
        }

        // What only a running session has, on the shell's own primitives
        // (the host's: the player, the capture buttons, the OSD and the
        // notifications; the login screen has none).
        Loader {
            anchors.fill: parent
            active: !xian.compact && !xian.still && xian.host.sessionComponent !== null && xian.host.sessionComponent !== undefined
            sourceComponent: xian.host.sessionComponent ?? null
            opacity: xian.uiIn
            onLoaded: {
                item.sc = Qt.binding(() => xian.sc);
                item.edge = Qt.binding(() => xian.edge);
                item.ctx = xian.ctx;
            }
        }

        // The session, bottom right: hold to confirm.
        Row {
            id: jadeTokens
            visible: !xian.compact
            anchors.right: parent.right
            anchors.rightMargin: xian.edge
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 44 * xian.sc
            spacing: 10 * xian.sc
            opacity: xian.uiIn

            Repeater {
                model: [
                    { zh: "眠", en: "Rest", act: "suspend" },
                    { zh: "轮", en: "Rebirth", act: "reboot" },
                    { zh: "寂", en: "Nirvana", act: "poweroff" }
                ]

                Token {
                    required property var modelData
                    glyph: modelData.zh
                    label: modelData.en
                    sc: xian.sc
                    hold: true
                    tone: Xian.jade
                    enabled: !xian.still
                    onActivated: xian.ctx[modelData.act]()
                }
            }
        }

        // Dao insights (achievements), top centre.
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 36 * xian.sc
            spacing: 10 * xian.sc
            visible: xian.granted && !xian.compact

            Repeater {
                model: xian.reward ? xian.reward.achievements.slice(0, 3) : []

                Rectangle {
                    id: insight
                    required property int index
                    required property var modelData
                    readonly property real appear: LockTheme.seg(xian.rewardIn, 0.15 + index * 0.18, 0.45 + index * 0.18)
                    width: 460 * xian.sc
                    height: 62 * xian.sc
                    radius: xian.host.radiusSmall * xian.sc
                    color: Xian.alpha(Xian.ink, 0.86)
                    border.width: 1 * xian.sc
                    border.color: Xian.alpha(Xian.gold, 0.6)
                    opacity: appear
                    transform: Translate { y: (1 - insight.appear) * -16 * xian.sc }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 18 * xian.sc
                        spacing: 16 * xian.sc

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "悟道"
                            font.family: Xian.cjk
                            font.weight: Font.Black
                            font.pixelSize: 22 * xian.sc
                            color: Xian.gold
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: "DAO INSIGHT  ·  " + insight.modelData.name.toUpperCase()
                                font.family: Xian.serif
                                font.pixelSize: 14 * xian.sc
                                font.letterSpacing: 2 * xian.sc
                                color: Xian.paper
                            }

                            Text {
                                text: insight.modelData.desc
                                font.family: Xian.serif
                                font.italic: true
                                font.pixelSize: 13 * xian.sc
                                color: Xian.paperDim
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Seals and omens over the formation ───────────────────────────
    component Seal: Rectangle {
        property string glyph
        width: 128 * xian.sc
        height: width
        radius: xian.host.radiusNormal * xian.sc
        rotation: -7
        color: Xian.cinnabar
        border.width: 3 * xian.sc
        border.color: Qt.darker(Xian.cinnabar, 1.35)

        Text {
            anchors.centerIn: parent
            text: parent.glyph
            font.family: Xian.cjk
            font.weight: Font.Black
            font.pixelSize: 88 * xian.sc
            color: Xian.paper
        }
    }

    Seal {
        glyph: "封"
        x: (xian.width - width) / 2
        y: xian.formationY - height / 2
        opacity: xian.sealIn * (1 - xian.sealOut)
        visible: opacity > 0
        scale: 2.6 - 1.6 * xian.sealIn
    }

    Seal {
        glyph: "开"
        x: (xian.width - width) / 2
        y: xian.formationY - height / 2
        opacity: xian.openIn
        visible: opacity > 0
        scale: 2.2 - 1.2 * Math.min(1, xian.openIn)
    }

    Rectangle {
        id: sealRing
        x: (xian.width - width) / 2
        y: xian.formationY - height / 2
        width: 150 * xian.sc
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 3 * xian.sc
        border.color: Xian.cinnabar
        opacity: 0
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: xian.formationY - height / 2
        opacity: xian.deviation
        visible: opacity > 0
        scale: 1.25 - 0.25 * xian.deviation

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "走火入魔"
            font.family: Xian.cjk
            font.weight: Font.Black
            font.pixelSize: 70 * xian.sc
            style: Text.Outline
            styleColor: Xian.ink
            color: Xian.cinnabar
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "QI DEVIATION"
            font.family: Xian.serif
            font.pixelSize: 16 * xian.sc
            font.letterSpacing: 8 * xian.sc
            style: Text.Outline
            styleColor: Xian.ink
            color: Xian.cinnabar
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: xian.formationY - height / 2
        opacity: xian.breakthrough
        visible: opacity > 0
        scale: 1.6 - 0.6 * Math.min(1, xian.breakthrough)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "突破"
            font.family: Xian.cjk
            font.weight: Font.Black
            font.pixelSize: 116 * xian.sc
            style: Text.Outline
            styleColor: Xian.alpha(Xian.ink, 0.8)
            color: Xian.goldHi
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "BREAKTHROUGH  ·  " + (xian.realm.en + (xian.realm.stageEn ? ", " + xian.realm.stageEn : "")).toUpperCase()
            font.family: Xian.serif
            font.pixelSize: 17 * xian.sc
            font.letterSpacing: 4 * xian.sc
            style: Text.Outline
            styleColor: Xian.ink
            color: Xian.paper
        }
    }

    // ── Choreography ─────────────────────────────────────────────────
    ParallelAnimation {
        id: intro
        SequentialAnimation {
            PauseAnimation { duration: Xian.d(80) }
            NumberAnimation { target: xian; property: "draw"; from: 0; to: 1; duration: Xian.d(650); easing.type: Easing.OutCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: Xian.d(380) }
            NumberAnimation { target: xian; property: "sealIn"; from: 0; to: 1; duration: Xian.d(190); easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            ScriptAction { script: { sealRingFx.restart(); stampShake.restart(); } }
        }
        SequentialAnimation {
            PauseAnimation { duration: Xian.d(460) }
            NumberAnimation { target: xian; property: "wash"; from: 0; to: 1; duration: Xian.d(420) }
        }
        SequentialAnimation {
            PauseAnimation { duration: Xian.d(540) }
            NumberAnimation { target: xian; property: "dissolve"; from: 0; to: 1; duration: Xian.d(900); easing.type: Easing.InOutSine }
        }
        SequentialAnimation {
            PauseAnimation { duration: Xian.d(1100) }
            NumberAnimation { target: xian; property: "sealOut"; from: 0; to: 1; duration: Xian.d(380) }
        }
        SequentialAnimation {
            PauseAnimation { duration: Xian.d(950) }
            NumberAnimation { target: xian; property: "uiIn"; from: 0; to: 1; duration: Xian.d(700); easing.type: Easing.OutCubic }
        }
    }

    // The formation bursts and the ink recedes from the centre: the last
    // frame is the desktop exactly.
    ParallelAnimation {
        id: outro
        NumberAnimation { target: xian; property: "uiIn"; to: 0; duration: Xian.d(280); easing.type: Easing.InQuad }
        NumberAnimation { target: xian; property: "burst"; to: 1; duration: Xian.d(520); easing.type: Easing.OutCubic }
        NumberAnimation { target: xian; property: "openIn"; to: 0; duration: Xian.d(300) }
        NumberAnimation { target: xian; property: "breakthrough"; to: 0; duration: Xian.d(300) }
        NumberAnimation { target: xian; property: "rewardIn"; to: 0; duration: Xian.d(250) }
        NumberAnimation { target: xian; property: "pillar"; to: 0; duration: Xian.d(300) }
        SequentialAnimation {
            PauseAnimation { duration: Xian.d(140) }
            PropertyAction { target: xian; property: "inward"; value: true }
            NumberAnimation { target: xian; property: "dissolve"; to: 0; duration: Xian.d(820); easing.type: Easing.InOutSine }
        }
        SequentialAnimation {
            PauseAnimation { duration: Xian.d(680) }
            NumberAnimation { target: xian; property: "wash"; to: 0; duration: Xian.d(420) }
        }
    }

    ParallelAnimation {
        id: sealRingFx
        NumberAnimation { target: sealRing; property: "scale"; from: 0.6; to: 3.4; duration: Xian.d(650); easing.type: Easing.OutCubic }
        NumberAnimation { target: sealRing; property: "opacity"; from: 0.9; to: 0; duration: Xian.d(650) }
    }

    SequentialAnimation {
        id: stampShake
        NumberAnimation { target: xian; property: "shakeY"; to: 7 * xian.sc; duration: Xian.d(45) }
        NumberAnimation { target: xian; property: "shakeY"; to: -4 * xian.sc; duration: Xian.d(70) }
        NumberAnimation { target: xian; property: "shakeY"; to: 0; duration: Xian.d(90) }
    }

    ParallelAnimation {
        id: deviationFx
        SequentialAnimation {
            NumberAnimation { target: xian; property: "alarm"; to: 1; duration: Xian.d(80) }
            NumberAnimation { target: xian; property: "alarm"; to: 0; duration: Xian.d(700) }
        }
        SequentialAnimation {
            NumberAnimation { target: xian; property: "deviation"; to: 1; duration: Xian.d(120) }
            PauseAnimation { duration: Xian.d(750) }
            NumberAnimation { target: xian; property: "deviation"; to: 0; duration: Xian.d(350) }
        }
        SequentialAnimation {
            NumberAnimation { target: xian; property: "shakeX"; to: -16 * xian.sc; duration: Xian.d(50) }
            NumberAnimation { target: xian; property: "shakeX"; to: 13 * xian.sc; duration: Xian.d(70) }
            NumberAnimation { target: xian; property: "shakeX"; to: -8 * xian.sc; duration: Xian.d(70) }
            NumberAnimation { target: xian; property: "shakeX"; to: 4 * xian.sc; duration: Xian.d(70) }
            NumberAnimation { target: xian; property: "shakeX"; to: 0; duration: Xian.d(80) }
        }
    }

    ParallelAnimation {
        id: grantFx
        NumberAnimation { target: xian; property: "surge"; to: 1; duration: Xian.d(220) }
        SequentialAnimation {
            NumberAnimation { target: xian; property: "openIn"; from: 0; to: 1; duration: Xian.d(220); easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            PauseAnimation { duration: Xian.d(450) }
            NumberAnimation { target: xian; property: "openIn"; to: 0; duration: Xian.d(300) }
        }
        SequentialAnimation {
            PauseAnimation { duration: Xian.d(120) }
            NumberAnimation { target: xian; property: "pillar"; to: 1; duration: Xian.d(240); easing.type: Easing.OutQuad }
            NumberAnimation { target: xian; property: "pillar"; to: 0; duration: Xian.d(950); easing.type: Easing.InQuad }
        }
        SequentialAnimation {
            PauseAnimation { duration: Xian.d(250) }
            NumberAnimation { target: xian; property: "rewardIn"; from: 0; to: 1; duration: Xian.d(800) }
        }
    }

    SequentialAnimation {
        id: qiFill
        PauseAnimation { duration: Xian.d(450) }
        NumberAnimation {
            target: xian
            property: "shownXp"
            to: xian.reward ? xian.reward.xpAfter : 0
            duration: Xian.d(800)
            easing.type: Easing.InOutCubic
        }
        PropertyAction { target: xian; property: "rewarding"; value: false }
    }

    NumberAnimation {
        id: breakthroughFx
        target: xian
        property: "breakthrough"
        from: 0
        to: 1
        duration: Xian.d(320)
        easing.type: Easing.OutBack
    }
}
