import QtQuick
import qs.config
import qs.services
import qs.components

// The command center's search, always at the top. Typing on any tab jumps to
// the launcher (services/Launcher.qml): a provider's keyword scopes the
// search to it (">" command, "=" calculate, "f " files, …); ":" opens the
// clipboard. Up/Down move through results, Enter runs the selected one,
// Shift+Enter its first action, Tab lists its actions (Shift+Tab / Esc back),
// Ctrl+Tab / Ctrl+Shift+Tab switch tabs, Esc closes.
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
        text: Launcher.scope?.icon ?? "search"
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
        }

        Keys.onPressed: event => {
            const ctrl = event.modifiers & Qt.ControlModifier;
            const shift = event.modifiers & Qt.ShiftModifier;
            if (event.key === Qt.Key_Escape) {
                if (!Launcher.hideActions())
                    ShellState.close();
            } else if (event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_N)) {
                root.cc.move(1);
            } else if (event.key === Qt.Key_Up || (ctrl && event.key === Qt.Key_P)) {
                root.cc.move(-1);
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.cc.activate(!!shift);
            } else if (ctrl && (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)) {
                root.cc.cycleTab(event.key === Qt.Key_Backtab || shift ? -1 : 1);
            } else if (event.key === Qt.Key_Tab && ShellState.ccTab === "apps") {
                Launcher.showActions();
            } else if (event.key === Qt.Key_Backtab && ShellState.ccTab === "apps") {
                Launcher.hideActions();
            } else {
                return;
            }
            event.accepted = true;
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            text: "Search apps, windows, settings, actions   ·   > command   ·   = calculate   ·   : clipboard"
            color: Colours.palette.m3onSurfaceVariant
            font.pixelSize: 14
        }
    }
}
