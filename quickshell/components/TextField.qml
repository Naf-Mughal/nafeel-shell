import QtQuick
import qs.config
import qs.services

// A filled M3 text field.
StyledRect {
    id: root

    property alias text: input.text
    property alias echoMode: input.echoMode
    property string placeholder
    // Optional: a function(event) that handles keys first (accept to stop).
    property var keyFilter: null
    signal accepted

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
        color: Colours.palette.m3onSurface
        selectionColor: Colours.palette.m3primary
        selectedTextColor: Colours.palette.m3onPrimary
        font.pixelSize: 13
        clip: true
        onAccepted: root.accepted()
        Keys.onEscapePressed: ShellState.close()
        Keys.onPressed: event => {
            if (root.keyFilter)
                root.keyFilter(event);
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            text: root.placeholder
            color: Colours.palette.m3onSurfaceVariant
            font.pixelSize: 13
        }
    }
}
