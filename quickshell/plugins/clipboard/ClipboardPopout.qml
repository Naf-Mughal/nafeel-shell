pragma ComponentBehavior: Bound

import QtQuick
import Nafeel
import qs.config
import qs.services
import qs.components

// The clipboard history (Noctalia's own clipboard, run by the shell; the same
// history and pins): search, the list (pinned first), a preview of the
// selection, and its actions. Enter pastes into the window you came from
// (Ctrl+Shift+V for text, Ctrl+V for images, as Noctalia's "auto"); Delete
// removes (press twice), Ctrl+P pins.
Panel {
    id: root

    property string query: ""
    // Indices into Clipboard.entries that match the search.
    readonly property var shown: {
        const q = query.trim().toLowerCase();
        const out = [];
        Clipboard.entries.forEach((e, i) => {
            if (!q || (e.preview ?? "").toLowerCase().includes(q))
                out.push(i);
        });
        return out;
    }
    property int sel: 0
    readonly property int index: shown[Math.min(sel, shown.length - 1)] ?? -1
    readonly property var entry: index >= 0 ? Clipboard.entries[index] : null
    // A destructive action waiting for its second press: "delete" | "clear".
    property string armed: ""

    function move(by: int): void {
        if (shown.length > 0)
            sel = Math.max(0, Math.min(shown.length - 1, sel + by));
        armed = "";
    }

    function paste(): void {
        if (index < 0)
            return;
        const i = index;
        // Close first so the window you came from has the keyboard again.
        ShellState.close();
        Clipboard.activate(i, true);
    }

    function removeSelected(): void {
        if (index < 0)
            return;
        if (armed !== "delete") {
            armed = "delete";
            return;
        }
        Clipboard.remove(index);
        armed = "";
    }

    function age(ms: real): string {
        const s = Math.max(0, (Date.now() - ms) / 1000);
        if (s < 60)
            return "now";
        if (s < 3600)
            return `${Math.floor(s / 60)} min`;
        if (s < 86400)
            return `${Math.floor(s / 3600)} h`;
        return `${Math.floor(s / 86400)} d`;
    }

    icon: "content_paste"
    title: "Clipboard"
    gloss: Xian.gloss.clipboard
    subtitle: {
        const n = Clipboard.entries.length;
        const note = Clipboard.state === "ready" ? "" : Clipboard.state === "opening" ? " · opening the history…" : " · history not saved (keyring)";
        return `${n} item${n === 1 ? "" : "s"}${note}`;
    }
    actions: [
        IconButton {
            icon: root.armed === "clear" ? "delete_forever" : "clear_all"
            size: 36
            filled: root.armed === "clear"
            fillColour: Colours.palette.m3errorContainer
            inkColour: Colours.palette.m3onErrorContainer
            onClicked: {
                if (root.armed !== "clear") {
                    root.armed = "clear";
                    return;
                }
                Clipboard.clearUnpinned();
                root.armed = "";
            }
        }
    ]

    onQueryChanged: sel = 0
    focusTarget: search

    TextField {
        id: search

        width: parent.width
        implicitHeight: 40
        placeholder: root.armed === "clear" ? "Press clear again to remove everything unpinned" : "Search the clipboard"
        onTextChanged: root.query = text
        onAccepted: root.paste()
        keyFilter: event => {
            const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
            if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                root.move(1);
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                root.move(-1);
            } else if (event.key === Qt.Key_Delete && search.text === "") {
                root.removeSelected();
            } else if (ctrl && event.key === Qt.Key_P) {
                if (root.index >= 0)
                    Clipboard.togglePin(root.index);
            } else {
                return;
            }
            event.accepted = true;
        }
    }

    Item {
        width: parent.width
        height: 340

        EmptyState {
            anchors.centerIn: parent
            visible: root.shown.length === 0
            icon: "content_paste_off"
            title: root.query ? "Nothing matches" : "Nothing copied yet"
        }

        // The list.
        Strip {
            id: list

            visible: root.shown.length > 0
            width: 250
            height: parent.height
            orientation: ListView.Vertical
            spacing: 2
            model: root.shown
            currentIndex: Math.min(root.sel, count - 1)
            centred: false
            highlightFollowsCurrentItem: false
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            delegate: Surface {
                id: row

                required property int modelData
                required property int index
                readonly property var e: Clipboard.entries[modelData] ?? ({})
                readonly property bool selected: index === root.sel

                width: list.width
                height: 48
                role: selected ? "secondary" : "paper"
                emphasis: selected ? "soft" : "ghost"
                interactive: true
                pressDepth: 1
                morph: false
                onClicked: {
                    root.sel = index;
                    root.armed = "";
                }

                TapHandler {
                    onDoubleTapped: root.paste()
                }

                MaterialIcon {
                    id: kind

                    anchors.left: parent.left
                    anchors.leftMargin: Tokens.spacing.normal
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.e.pinned ? "push_pin" : row.e.image ? "image" : "notes"
                    fill: row.e.pinned ? 1 : 0
                    color: row.selected ? row.ink : row.subInk
                    size: 18
                }

                Column {
                    anchors.left: kind.right
                    anchors.leftMargin: Tokens.spacing.normal
                    anchors.right: parent.right
                    anchors.rightMargin: Tokens.spacing.normal
                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        width: parent.width
                        text: row.e.image ? "Image" : (row.e.preview ?? "").replace(/\s+/g, " ").trim() || "(empty)"
                        color: row.ink
                        font.pixelSize: Tokens.font.body
                        elide: Text.ElideRight
                    }

                    MicroLabel {
                        text: `${root.age(row.e.time ?? 0)} · ${(row.e.mime ?? "").replace("text/plain;charset=utf-8", "text")}`
                    }
                }
            }
        }

        // The preview and its actions.
        Surface {
            visible: root.entry !== null
            anchors.left: list.right
            anchors.leftMargin: Tokens.spacing.normal
            anchors.right: parent.right
            height: parent.height
            level: 2

            Scroller {
                id: textView

                visible: root.entry !== null && !root.entry.image
                anchors.fill: parent
                anchors.margins: Tokens.spacing.normal
                anchors.bottomMargin: actionsRow.height + Tokens.spacing.normal * 2
                contentHeight: body.implicitHeight
                clip: true

                StyledText {
                    id: body

                    width: textView.width
                    // The whole text, loaded once per selection.
                    text: root.entry && !root.entry.image ? Clipboard.text(root.index) : ""
                    wrapMode: Text.WrapAnywhere
                    font.family: Tokens.font.mono
                    font.pixelSize: Tokens.font.small
                    color: Colours.palette.m3onSurface
                }
            }

            Image {
                visible: root.entry?.image ?? false
                anchors.fill: parent
                anchors.margins: Tokens.spacing.normal
                anchors.bottomMargin: actionsRow.height + Tokens.spacing.normal * 2
                source: root.entry?.image ? Clipboard.imageUrl(root.index) : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }

            Row {
                id: actionsRow

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Tokens.spacing.normal
                spacing: Tokens.spacing.small
                layoutDirection: Qt.RightToLeft

                IconButton {
                    icon: "content_paste_go"
                    filled: true
                    size: 40
                    onClicked: root.paste()
                }

                IconButton {
                    icon: "push_pin"
                    filled: root.entry?.pinned ?? false
                    size: 40
                    onClicked: Clipboard.togglePin(root.index)
                }

                IconButton {
                    icon: root.armed === "delete" ? "delete_forever" : "delete"
                    filled: root.armed === "delete"
                    fillColour: Colours.palette.m3errorContainer
                    inkColour: Colours.palette.m3onErrorContainer
                    size: 40
                    onClicked: root.removeSelected()
                }
            }
        }
    }
}
