import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Type to launch from umbriel's overview (as Noctalia's overview launcher
// capture did): while the overview is open, an invisible surface on the
// focused screen holds the keyboard (the pointer passes through to the
// overview). The first letter typed closes the overview and opens the
// launcher with it; Enter and Esc close the overview; the arrows still move
// between windows and workspaces. Switched on and off as a plugin.
Scope {
    id: root

    readonly property bool on: Umbriel.overviewOpen

    Variants {
        model: root.on ? Quickshell.screens.filter(s => s.name === Umbriel.focusedOutput || (Umbriel.focusedOutput === "" && s === Quickshell.screens[0])) : []

        PanelWindow {
            required property ShellScreen modelData

            screen: modelData
            anchors {
                top: true
                left: true
            }
            implicitWidth: 1
            implicitHeight: 1
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "nafeel-shell-overview-keys"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            // No pointer input at all: clicks reach the overview.
            mask: Region {}

            Item {
                anchors.fill: parent
                focus: true
                Component.onCompleted: forceActiveFocus()
                Keys.onPressed: event => {
                    event.accepted = true;
                    switch (event.key) {
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                    case Qt.Key_Escape:
                        Umbriel.dispatch("overview-toggle");
                        return;
                    case Qt.Key_Left:
                        Umbriel.dispatch("window-focus-left");
                        return;
                    case Qt.Key_Right:
                        Umbriel.dispatch("window-focus-right");
                        return;
                    case Qt.Key_Up:
                        Umbriel.dispatch("window-focus-or-workspace-up");
                        return;
                    case Qt.Key_Down:
                        Umbriel.dispatch("window-focus-or-workspace-down");
                        return;
                    }
                    const text = event.text;
                    if (text.length > 0 && text.charCodeAt(0) > 0x20 && text.charCodeAt(0) !== 0x7f && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                        Umbriel.dispatch("overview-close");
                        ShellState.ccTab = "apps";
                        ShellState.ccQuery = text;
                        ShellState.pin("command", Umbriel.focusedOutput);
                        ShellState.ccFocus++;
                        return;
                    }
                    event.accepted = false;
                }
            }
        }
    }
}
