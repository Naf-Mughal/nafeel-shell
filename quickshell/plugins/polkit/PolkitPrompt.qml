pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// An authentication prompt (polkit), out of the bottom centre: a Panel with
// what's asking and why, who to authenticate as (when there's a choice),
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

    Component.onCompleted: Qt.callLater(() => password.focusInput())

    // What's asking: its icon and its message.
    Surface {
        width: parent.width
        height: ask.implicitHeight + Tokens.spacing.large * 2
        role: "paper"
        level: 2

        Row {
            id: ask

            x: Tokens.spacing.large
            y: Tokens.spacing.large
            width: parent.width - Tokens.spacing.large * 2
            spacing: Tokens.spacing.normal

            IconImage {
                id: askIcon

                anchors.verticalCenter: parent.verticalCenter
                visible: (root.flow?.iconName ?? "") !== ""
                implicitSize: 36
                source: visible ? Quickshell.iconPath(root.flow.iconName, "dialog-password") : ""
            }

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                visible: !askIcon.visible
                text: "lock"
                fill: 1
                size: 30
                color: Colours.palette.m3primary
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 36 - Tokens.spacing.normal
                text: root.flow?.message ?? ""
                font.pixelSize: Tokens.font.body
                wrapMode: Text.Wrap
            }
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
