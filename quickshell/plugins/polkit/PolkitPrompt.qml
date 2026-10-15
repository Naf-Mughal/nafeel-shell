pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services
import "../lock"
import "../lock/themes/xianxia"

// A polkit request as the lock takes a passcode: the sealing formation
// floating in the centre over a veil, typed straight into (an invisible
// field: every layout, compose and IME work), a rune lighting per character.
// Enter offers it; a wrong one flushes the formation cinnabar; granted, it
// blazes gold, 准, and shows the cultivation earned. Esc leaves (the request
// is cancelled); Tab changes who to authenticate as, when there's a choice.
Item {
    id: root

    required property var polkit
    property real fade: 1

    readonly property var flow: polkit.flow
    readonly property bool granted: polkit.granted
    readonly property var gain: polkit.gain
    readonly property var identities: flow?.identities ?? []
    readonly property var realm: Xian.realm(Math.max(1, LockStats.level))
    readonly property real sc: Math.max(0.6, Math.min(1, height / 1200))

    readonly property QtObject seal: QtObject {
        property int cells: 0
        property bool denying: false
        readonly property string phase: root.granted ? "granted" : root.polkit.weighing ? "verifying" : "ready"
        readonly property date now: new Date()
        readonly property string timeText: ""
    }

    function identityName(i: var): string {
        return i?.displayName || i?.name || String(i ?? "");
    }

    // The theme's colours from the shell (when the lock hasn't set them).
    ShellLockHost {
        id: lockHost
    }

    Component.onCompleted: {
        if (!Xian.host)
            Xian.host = lockHost;
        drawIn.start();
        input.forceActiveFocus();
    }
    Component.onDestruction: if (Xian.host === lockHost)
        Xian.host = null

    property real draw: 0
    property real spin: 0
    property real alarm: 0
    property real surge: granted ? 1 : 0

    Behavior on surge {
        NumberAnimation {
            duration: Xian.d(500)
        }
    }

    NumberAnimation on spin {
        running: Xian.motion > 0
        from: 0
        to: 360
        duration: 120000
        loops: Animation.Infinite
    }

    NumberAnimation {
        id: drawIn

        target: root
        property: "draw"
        from: 0
        to: 1
        duration: Xian.d(1100)
        easing.type: Easing.OutCubic
    }

    // A wrong one: the formation flushes cinnabar, the runes with it.
    SequentialAnimation {
        id: deny

        ScriptAction {
            script: root.seal.denying = true
        }
        NumberAnimation {
            target: root
            property: "alarm"
            to: 1
            duration: Xian.d(120)
        }
        PauseAnimation {
            duration: Xian.d(350)
        }
        ScriptAction {
            script: {
                root.seal.cells = 0;
                input.text = "";
            }
        }
        NumberAnimation {
            target: root
            property: "alarm"
            to: 0
            duration: Xian.d(700)
        }
        ScriptAction {
            script: root.seal.denying = false
        }
    }

    Connections {
        target: root.polkit

        function onFailuresChanged(): void {
            deny.restart();
        }
        function onFlowChanged(): void {
            input.text = "";
            root.seal.cells = 0;
            input.forceActiveFocus();
        }
        function onPreviewChanged(): void {
            if (root.polkit.preview) {
                input.text = "";
                drawIn.restart();
                input.forceActiveFocus();
            }
        }
    }

    // The veil.
    Rectangle {
        anchors.fill: parent
        color: Xian.alpha(Xian.ink, 0.62 * root.fade)
    }

    // Clicks anywhere give the keyboard back to the formation.
    MouseArea {
        anchors.fill: parent
        onPressed: input.forceActiveFocus()
    }

    TextInput {
        id: input

        width: 1
        height: 1
        opacity: 0
        focus: true
        echoMode: TextInput.Password
        passwordMaskDelay: 0
        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase | Qt.ImhHiddenText
        readOnly: root.polkit.weighing || root.granted || root.seal.denying
        selectByMouse: false

        onTextChanged: if (!root.seal.denying)
            root.seal.cells = Math.min(12, text.length)
        onAccepted: {
            const t = text;
            text = "";
            root.seal.cells = Math.min(12, t.length);
            root.polkit.submit(t);
        }
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.polkit.cancel();
                event.accepted = true;
            } else if (event.key === Qt.Key_Tab && root.identities.length > 1) {
                const i = root.identities.indexOf(root.flow.selectedIdentity);
                root.flow.selectedIdentity = root.identities[(i + 1) % root.identities.length];
                event.accepted = true;
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 18 * root.sc
        opacity: root.fade
        scale: 0.96 + 0.04 * root.fade

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: formation.width
            height: formation.height

            Formation {
                id: formation

                ctx: root.seal
                sc: root.sc
                draw: root.draw
                spin: root.spin
                alarm: root.alarm
                surge: root.surge
                hush: 1
            }

            // The centre: 授 (asked) or 准 (granted), and your realm; once
            // granted, what it earned.
            Column {
                anchors.centerIn: parent
                spacing: 6 * root.sc
                opacity: LockTheme.seg(root.draw, 0.45, 1)

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.granted ? "准" : "授"
                    font.family: Xian.cjk
                    font.pixelSize: 84 * root.sc
                    color: Qt.tint(Qt.tint(Xian.gold, Xian.alpha(Xian.cinnabar, root.alarm)), Xian.alpha(Xian.goldHi, root.surge))
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.granted && root.gain ? (root.gain.levelAfter > root.gain.levelBefore ? "突破 · " : "") + `修为 +${root.gain.total}` : `${root.realm.zh} ${root.realm.stageZh}`
                    font.family: Xian.cjk
                    font.pixelSize: 17 * root.sc
                    font.letterSpacing: 4 * root.sc
                    color: root.granted ? Xian.goldHi : Xian.paperDim
                }
            }
        }

        // What's asking, and why.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10 * root.sc

            IconImage {
                id: askIcon

                anchors.verticalCenter: parent.verticalCenter
                visible: !root.granted && (root.flow?.iconName ?? "") !== ""
                implicitSize: 22 * root.sc
                source: visible ? Quickshell.iconPath(root.flow.iconName, "dialog-password") : ""
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, root.width * 0.6)
                text: root.granted ? `${root.realm.en}${root.realm.stageEn ? ", " + root.realm.stageEn : ""}. The seal yields` : root.polkit.preview ? "A pretend request: “wrong” is refused, anything else granted" : root.flow?.message ?? ""
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                font.family: Xian.serif
                font.pixelSize: 18 * root.sc
                color: Xian.paper
            }
        }

        // The state, in the lock's words.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !root.granted
            text: root.polkit.weighing ? "The formation weighs your incantation…" : root.seal.cells > 0 ? root.seal.cells + (root.seal.cells === 1 ? " rune" : " runes") + " kindled" : "Recite the incantation to grant it"
            font.family: Xian.serif
            font.italic: true
            font.pixelSize: 15 * root.sc
            color: Xian.paperDim
        }

        // Wrong, polkit's own words, or Caps Lock.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, root.width * 0.6)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            visible: text !== "" && !root.granted
            text: root.flow?.supplementaryMessage || (root.polkit.misses > 0 ? "The incantation was refused. Recite it again" : LockKeys.caps ? "Caps Lock is on. Incantations are case-sensitive" : "")
            font.family: Xian.serif
            font.pixelSize: 14 * root.sc
            color: Xian.cinnabar
        }

        // Who, and the keys.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !root.granted
            text: (root.identities.length > 1 ? `As ${root.identityName(root.flow?.selectedIdentity)} · Tab for another · ` : "") + "Enter to grant · Esc to leave"
            font.family: Xian.serif
            font.pixelSize: 13 * root.sc
            color: Xian.alpha(Xian.paperDim, 0.7)
        }
    }
}
