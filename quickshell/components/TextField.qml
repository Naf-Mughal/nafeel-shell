pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// A filled M3 text field. Typing answers as Appearance → Typing says (any
// together): "goo" the caret an ink drop springing to its place, "trail" a
// cut when the caret jumps, "ink" letters soaking in, "brush" a stroke under
// the text flowing to the caret. `typing` overrides it for one field. A
// password with `seals` shows seals melting into dots (PasswordSeals).
StyledRect {
    id: root

    property alias text: input.text
    property alias echoMode: input.echoMode
    property string placeholder
    // Optional: a function(event) that handles keys first (accept to stop).
    property var keyFilter: null
    property var typing: Tokens.typing
    property bool seals: false
    signal accepted

    readonly property bool password: input.echoMode === TextInput.Password
    readonly property bool sealed: password && seals

    function has(style: string): bool {
        return !Tokens.reduceMotion && (typing ?? []).indexOf(style) >= 0;
    }

    function focusInput(): void {
        input.forceActiveFocus();
    }

    implicitHeight: 44
    radius: Tokens.rounding.small
    color: Colours.palette.m3surfaceContainerHighest
    border.width: input.activeFocus ? 2 : 0
    border.color: Colours.palette.m3primary

    TextInput {
        id: input

        anchors.fill: parent
        anchors.leftMargin: Tokens.spacing.normal
        anchors.rightMargin: Tokens.spacing.normal
        verticalAlignment: TextInput.AlignVCenter
        color: root.sealed ? "transparent" : Colours.palette.m3onSurface
        selectionColor: Colours.palette.m3primary
        selectedTextColor: Colours.palette.m3onPrimary
        font.pixelSize: 13
        clip: true
        // Seals: no caret (the hidden text is narrower than the seals).
        cursorDelegate: root.sealed ? noCaret : root.has("goo") ? gooCaret : null
        onAccepted: root.accepted()
        Keys.onEscapePressed: ShellState.close()
        Keys.onPressed: event => {
            if (root.keyFilter)
                root.keyFilter(event);
        }

        TypingInk {
            target: input
            enabled: root.has("ink") && !root.sealed
            paper: root.color
            mask: root.password ? input.passwordCharacter : ""
        }

        TypingBrush {
            target: input
            enabled: root.has("brush") && !root.sealed
        }

        CaretTrail {
            target: input
            enabled: root.has("trail") && !root.sealed
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            text: root.placeholder
            color: Colours.palette.m3onSurfaceVariant
            font.pixelSize: 13
        }
    }

    PasswordSeals {
        visible: root.sealed
        anchors.fill: input
        count: root.sealed ? input.text.length : 0
    }

    Component {
        id: noCaret

        Item {}
    }

    Component {
        id: gooCaret

        GooCaret {}
    }
}
