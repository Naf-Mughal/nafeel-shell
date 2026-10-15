pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components
import "../lock"
import "../lock/themes/xianxia"

// An authentication prompt (polkit), out of the bottom centre: a Panel with
// the lock's sealing formation (a rune lights per character, cinnabar on a
// wrong password, gold when granted, with the cultivation it earned), what's
// asking and why, who to authenticate as (when there's a choice),
// the password, and Cancel / Authenticate. Caps Lock is pointed out, a
// wrong password shakes the field and says so, Esc cancels. The action's id
// shows on request (Details).
Panel {
    id: root

    // The agent (the plugin's root).
    readonly property var polkit: Plugins.instance("polkit")
    readonly property var flow: polkit?.flow ?? null
    readonly property var identities: flow?.identities ?? []
    property bool details: false

    function submit(): void {
        if (root.flow && password.text !== "") {
            root.flow.submit(password.text);
            password.text = "";
        }
    }

    function identityName(i: var): string {
        return i?.displayName || i?.name || String(i ?? "");
    }

    icon: "admin_panel_settings"
    title: "Authentication"
    gloss: "授权"
    subtitle: "An action needs your password"
    focusTarget: password

    // Ready to type at every prompt: the panel is built ahead (prewarmed)
    // and kept, so focus is taken each time it shows or a new request comes
    // (once more a beat later, after the frame window's keyboard grab).
    function focusPrompt(): void {
        if (!visible)
            return;
        password.focusInput();
        refocus.restart();
    }

    onVisibleChanged: {
        Qt.callLater(focusPrompt);
        if (visible)
            drawIn.restart();
    }
    onFlowChanged: Qt.callLater(focusPrompt)
    Component.onCompleted: {
        Qt.callLater(focusPrompt);
        drawIn.restart();
    }

    Timer {
        id: refocus

        interval: 120
        onTriggered: {
            if (root.visible && !password.activeFocus)
                password.focusInput();
        }
    }

    // The lock's formation, small: what the runes and the centre read.
    readonly property bool granted: polkit?.granted ?? false
    readonly property var gain: polkit?.gain ?? null
    readonly property int level: LockStats.level
    readonly property var realm: Xian.realm(Math.max(1, level))
    readonly property QtObject seal: QtObject {
        readonly property int cells: Math.min(12, password.text.length)
        property bool denying: false
        readonly property string phase: root.granted ? "granted" : "ready"
        readonly property date now: new Date()
        readonly property string timeText: ""
    }

    // The theme's colours from the shell (when the lock hasn't set them).
    ShellLockHost {
        id: lockHost
    }
    Component.onDestruction: if (Xian.host === lockHost)
        Xian.host = null

    property real draw: 0
    property real spin: 0
    property real alarm: 0
    property real surge: granted ? 1 : 0

    Behavior on surge {
        Anim {
            duration: Xian.d(500)
        }
    }

    NumberAnimation on spin {
        running: root.visible && Xian.motion > 0
        from: 0
        to: 360
        duration: 120000
        loops: Animation.Infinite
    }

    SequentialAnimation {
        id: drawIn

        ScriptAction {
            script: {
                if (!Xian.host)
                    Xian.host = lockHost;
                root.draw = 0;
            }
        }
        NumberAnimation {
            target: root
            property: "draw"
            to: 1
            duration: Xian.d(900)
            easing.type: Easing.OutCubic
        }
    }

    // A wrong password: the formation flushes cinnabar, the runes with it.
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
            duration: Xian.d(300)
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

    Item {
        width: parent.width
        height: formation.height * 0.86

        Formation {
            id: formation

            anchors.centerIn: parent
            ctx: root.seal
            sc: 0.44
            draw: root.draw
            spin: root.spin
            alarm: root.alarm
            surge: root.surge
            hush: 1
        }

        // The centre: what's asked (授, granted 准), and your realm; once
        // granted, what it earned.
        Column {
            anchors.centerIn: parent
            spacing: 2
            opacity: LockTheme.seg(root.draw, 0.4, 1)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.granted ? "准" : "授"
                font.family: Xian.cjk
                font.pixelSize: 38
                color: Qt.tint(Qt.tint(Xian.gold, Xian.alpha(Xian.cinnabar, root.alarm)), Xian.alpha(Xian.goldHi, root.surge))
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.granted && root.gain ? (root.gain.levelAfter > root.gain.levelBefore ? "突破 · " : "") + `+${root.gain.total} 修为` : `${root.realm.zh} ${root.realm.stageZh}`
                font.family: Xian.cjk
                font.pixelSize: 12
                color: root.granted ? Xian.goldHi : Xian.paperDim
            }
        }
    }

    // What's asking, and why.
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(implicitWidth, parent.width)
        spacing: Tokens.spacing.small

        IconImage {
            id: askIcon

            anchors.verticalCenter: parent.verticalCenter
            visible: (root.flow?.iconName ?? "") !== ""
            implicitSize: 20
            source: visible ? Quickshell.iconPath(root.flow.iconName, "dialog-password") : ""
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.width - (askIcon.visible ? 28 : 0) - Tokens.spacing.large * 2)
            text: root.granted ? `${root.realm.en}${root.realm.stageEn ? ", " + root.realm.stageEn : ""} · the seal opens` : root.flow?.message ?? ""
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Tokens.font.body
            wrapMode: Text.Wrap
        }
    }

    // Who: a choice only when there is one.
    Sheet {
        width: parent.width
        visible: root.identities.length > 1
        eyebrow: "Authenticate as"

        Flow {
            width: parent.width
            spacing: Tokens.spacing.small

            Repeater {
                model: root.identities

                Chip {
                    required property var modelData

                    icon: "person"
                    text: root.identityName(modelData)
                    selected: root.flow?.selectedIdentity === modelData
                    onClicked: root.flow.selectedIdentity = modelData
                }
            }
        }
    }

    TextField {
        id: password

        width: parent.width
        placeholder: (root.flow?.inputPrompt || "Password").replace(/:\s*$/, "")
        echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
        onAccepted: root.submit()
        // Esc cancels the request (not just the panel).
        keyFilter: event => {
            if (event.key === Qt.Key_Escape) {
                root.flow?.cancelAuthenticationRequest();
                event.accepted = true;
            }
        }

        // Shake on a wrong password.
        transform: Translate {
            id: shake
        }

        Connections {
            target: root.polkit

            function onFailuresChanged(): void {
                shakeAnim.restart();
                deny.restart();
                password.focusInput();
            }
        }

        SequentialAnimation {
            id: shakeAnim

            NumberAnimation {
                target: shake
                property: "x"
                to: -10
                duration: Tokens.dur(50)
            }
            NumberAnimation {
                target: shake
                property: "x"
                to: 10
                duration: Tokens.dur(70)
            }
            NumberAnimation {
                target: shake
                property: "x"
                to: -6
                duration: Tokens.dur(60)
            }
            SpringAnimation {
                target: shake
                property: "x"
                to: 0
                spring: Tokens.spring.bouncy.spring
                damping: Tokens.spring.bouncy.damping
            }
        }
    }

    // What polkit says (an error in the error colour), and Caps Lock.
    StyledText {
        width: parent.width
        visible: text !== ""
        text: root.flow?.supplementaryMessage || ((root.polkit?.failures ?? 0) > 0 ? "That password didn't work. Try again." : "")
        color: root.flow?.supplementaryIsError || (root.polkit?.failures ?? 0) > 0 ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
        font.pixelSize: Tokens.font.small
        wrapMode: Text.Wrap
    }

    Row {
        visible: LockKeys.caps
        spacing: Tokens.spacing.small

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: "keyboard_capslock"
            size: 16
            color: Colours.palette.m3tertiary
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: "Caps Lock is on"
            color: Colours.palette.m3tertiary
            font.pixelSize: Tokens.font.small
        }
    }

    // Details on the left, the answers on the right.
    Item {
        width: parent.width
        height: 40

        Chip {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            icon: root.details ? "expand_less" : "info"
            text: "Details"
            selected: root.details
            onClicked: root.details = !root.details
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.spacing.small

            Surface {
                width: cancelLabel.implicitWidth + Tokens.spacing.large * 2
                height: 40
                role: "secondary"
                emphasis: "soft"
                interactive: true
                onClicked: root.flow?.cancelAuthenticationRequest()

                StyledText {
                    id: cancelLabel

                    anchors.centerIn: parent
                    text: "Cancel"
                    color: parent.ink
                    font.pixelSize: Tokens.font.body
                    font.weight: Font.DemiBold
                }
            }

            Surface {
                width: okLabel.implicitWidth + Tokens.spacing.large * 2
                height: 40
                role: "primary"
                emphasis: "strong"
                interactive: true
                onClicked: root.submit()

                StyledText {
                    id: okLabel

                    anchors.centerIn: parent
                    text: "Authenticate"
                    color: parent.ink
                    font.pixelSize: Tokens.font.body
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    MicroLabel {
        width: parent.width
        visible: root.details
        text: root.flow?.actionId ?? ""
        wrapMode: Text.WrapAnywhere
    }
}
