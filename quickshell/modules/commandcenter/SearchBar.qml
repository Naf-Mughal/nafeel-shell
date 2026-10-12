import QtQuick
import qs.config
import qs.services
import qs.components

// The command center's search, always at the top. Typing on any tab jumps to
// the launcher; ">" runs a command, "=" calculates, ":" opens the clipboard.
// Up/Down move through results, Enter runs the selected one, Ctrl+Tab /
// Ctrl+Shift+Tab switch tabs, Esc closes.
StyledRect {
    id: root

    required property var cc

    function focusInput(): void {
        input.forceActiveFocus();
    }

    implicitHeight: 52
    radius: Tokens.rounding.normal
    color: Colours.palette.m3surfaceContainerHigh
    border.width: input.activeFocus ? 2 : 0
    border.color: Colours.palette.m3primary

    MaterialIcon {
        id: lead

        anchors.left: parent.left
        anchors.leftMargin: Tokens.spacing.large
        anchors.verticalCenter: parent.verticalCenter
        text: root.cc.mode === "command" ? "terminal" : root.cc.mode === "calc" ? "calculate" : "search"
        color: Colours.palette.m3onSurfaceVariant
    }

    TextInput {
        id: input

        anchors.left: lead.right
        anchors.leftMargin: Tokens.spacing.normal
        anchors.right: parent.right
        anchors.rightMargin: Tokens.spacing.large
        anchors.verticalCenter: parent.verticalCenter
        text: ShellState.ccQuery
        color: Colours.palette.m3onSurface
        selectionColor: Colours.palette.m3primary
        selectedTextColor: Colours.palette.m3onPrimary
        font.pixelSize: 15
        clip: true

        onTextEdited: {
            if (text.startsWith(":")) {
                ShellState.ccQuery = "";
                // The clipboard panel, in the top-left corner by its bar icon.
                ShellState.anchorTo("bar:clipboard");
                ShellState.pin("bar:clipboard", Umbriel.focusedOutput);
                return;
            }
            ShellState.ccQuery = text;
            if (text !== "")
                ShellState.ccTab = "apps";
            root.cc.selected = 0;
        }

        Keys.onPressed: event => {
            const ctrl = event.modifiers & Qt.ControlModifier;
            if (event.key === Qt.Key_Escape) {
                ShellState.close();
            } else if (event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_N)) {
                root.cc.move(1);
            } else if (event.key === Qt.Key_Up || (ctrl && event.key === Qt.Key_P)) {
                root.cc.move(-1);
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.cc.activate();
            } else if (ctrl && (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)) {
                root.cc.cycleTab(event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier) ? -1 : 1);
            } else {
                return;
            }
            event.accepted = true;
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            text: "Search apps   ·   > command   ·   = calculate   ·   : clipboard"
            color: Colours.palette.m3onSurfaceVariant
            font.pixelSize: 14
        }
    }
}
