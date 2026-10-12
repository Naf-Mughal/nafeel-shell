pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.components

// Notes (Mod+X): your notes (NotesStore: Markdown files in ~/Documents/Notes)
// beside the open one. The Scratchpad sits at the top, pinned notes after it,
// then the most recently changed. The editor saves a moment after you stop
// typing, when you switch notes and when the drawer closes; the title renames
// the file (Enter). Preview shows the Markdown rendered.
//
// Keys: Ctrl+N new · Ctrl+F search · Ctrl+↑/↓ previous / next note ·
//       Ctrl+P pin · Ctrl+E preview · Ctrl+S save · Ctrl+Delete delete
//       (press twice) · Esc close
Item {
    id: root

    // The plugin's store (its root's; see Plugin.qml).
    readonly property var store: Plugins.instance("notes")?.store ?? null

    property string current: store.last
    readonly property var note: store.notes.find(n => n.name === current) ?? null
    property string query: ""
    readonly property var shown: {
        const q = query.trim().toLowerCase();
        return q ? store.notes.filter(n => n.name.toLowerCase().includes(q) || (n.preview ?? "").toLowerCase().includes(q)) : store.notes;
    }
    property bool preview: false
    property bool loaded: false
    property real savedAt: 0
    property bool armed: false
    readonly property int words: edit.text.trim() ? edit.text.trim().split(/\s+/).length : 0

    function focusEditor(): void {
        if (preview)
            return;
        edit.forceActiveFocus();
    }

    // Write what's pending now (switching notes, closing).
    function flush(): void {
        if (save.running) {
            save.stop();
            file.setText(edit.text);
            store.saved();
        }
    }

    function openNote(name: string): void {
        if (name === current)
            return;
        flush();
        armed = false;
        loaded = false;
        current = name;
        store.open(name);
    }

    function step(by: int): void {
        const i = shown.findIndex(n => n.name === current);
        const next = shown[Math.max(0, Math.min(shown.length - 1, i + by))];
        if (next)
            openNote(next.name);
    }

    function newNote(): void {
        flush();
        const name = store.create("");
        loaded = false;
        current = name;
        preview = false;
        Qt.callLater(() => title.forceActiveFocus());
    }

    function removeCurrent(): void {
        if (!note || note.scratch)
            return;
        if (!armed) {
            armed = true;
            disarm.restart();
            return;
        }
        armed = false;
        save.stop();
        store.remove(current);
        current = store.scratchName;
    }

    // Shared keys (editor, title, search, list).
    function keys(event: var): bool {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        if (event.key === Qt.Key_Escape) {
            flush();
            ShellState.close();
        } else if (!ctrl) {
            return false;
        } else if (event.key === Qt.Key_N) {
            newNote();
        } else if (event.key === Qt.Key_F) {
            search.focusInput();
        } else if (event.key === Qt.Key_Up) {
            step(-1);
        } else if (event.key === Qt.Key_Down) {
            step(1);
        } else if (event.key === Qt.Key_P) {
            store.togglePin(current);
        } else if (event.key === Qt.Key_E) {
            preview = !preview;
            if (!preview)
                Qt.callLater(focusEditor);
        } else if (event.key === Qt.Key_S) {
            save.stop();
            file.setText(edit.text);
            savedAt = Date.now();
            store.saved();
        } else if (event.key === Qt.Key_Delete) {
            removeCurrent();
        } else {
            return false;
        }
        event.accepted = true;
        return true;
    }

    Component.onCompleted: Qt.callLater(focusEditor)
    Component.onDestruction: flush()

    // The keyboard goes to the editor when the drawer is pinned.
    Connections {
        target: ShellState

        function onKeyboardGranted(req: var): void {
            if (ShellState.pinned === "notes") {
                root.focusEditor();
                req.taken = true;
            }
        }
    }

    Timer {
        id: disarm

        interval: 3000
        onTriggered: root.armed = false
    }

    FileView {
        id: file

        path: root.current ? store.pathOf(root.current) : ""
        printErrors: false
        onLoaded: {
            edit.text = text();
            root.loaded = true;
            Qt.callLater(root.focusEditor);
        }
        onLoadFailed: {
            edit.text = "";
            root.loaded = true;
        }
    }

    Timer {
        id: save

        interval: 700
        onTriggered: {
            file.setText(edit.text);
            root.savedAt = Date.now();
            store.saved();
        }
    }

    // ── Heading ──
    Item {
        id: head

        width: parent.width
        height: 40

        GlossTitle {
            anchors.verticalCenter: parent.verticalCenter
            text: "Notes"
            gloss: Xian.gloss.notes
            size: Tokens.font.value
        }

        MicroLabel {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: `${store.notes.length} notes · ${root.words} words · ${save.running ? "saving" : root.savedAt ? "saved" : "ready"}`
        }
    }

    // ── The list ──
    Column {
        id: side

        anchors.top: head.bottom
        anchors.topMargin: Tokens.spacing.small
        anchors.bottom: parent.bottom
        width: 220
        spacing: Tokens.spacing.small

        Row {
            width: parent.width
            spacing: Tokens.spacing.small

            TextField {
                id: search

                width: parent.width - newButton.width - Tokens.spacing.small
                implicitHeight: 36
                placeholder: "Search notes"
                onTextChanged: root.query = text
                onAccepted: {
                    if (root.shown.length > 0)
                        root.openNote(root.shown[0].name);
                    root.focusEditor();
                }
                keyFilter: event => root.keys(event)
            }

            IconButton {
                id: newButton

                icon: "add"
                size: 36
                filled: true
                onClicked: root.newNote()
            }
        }

        Strip {
            id: list

            width: parent.width
            height: parent.height - 36 - Tokens.spacing.small
            orientation: ListView.Vertical
            spacing: 2
            centred: false
            model: root.shown

            delegate: Surface {
                id: row

                required property var modelData
                readonly property bool on: modelData.name === root.current

                width: list.width
                height: 50
                role: on ? "secondary" : "paper"
                emphasis: on ? "soft" : "ghost"
                interactive: true
                pressDepth: 1
                morph: false
                onClicked: root.openNote(modelData.name)

                MaterialIcon {
                    id: kind

                    anchors.left: parent.left
                    anchors.leftMargin: Tokens.spacing.normal
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.scratch ? "edit_note" : row.modelData.pinned ? "push_pin" : "description"
                    fill: row.modelData.pinned ? 1 : 0
                    color: row.on ? row.ink : row.subInk
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
                        text: row.modelData.name
                        color: row.ink
                        font.pixelSize: Tokens.font.body
                        elide: Text.ElideRight
                    }

                    MicroLabel {
                        width: parent.width
                        text: row.modelData.preview || "empty"
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    // ── The open note ──
    Surface {
        id: page

        anchors.top: head.bottom
        anchors.topMargin: Tokens.spacing.small
        anchors.left: side.right
        anchors.leftMargin: Tokens.spacing.normal
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        level: 1
        border.width: edit.activeFocus ? 1 : 0
        border.color: Qt.alpha(Colours.palette.m3primary, 0.5)

        // Title (renames the file) and the note's actions.
        Item {
            id: bar

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.spacing.normal
            height: 34

            TextInput {
                id: title

                anchors.left: parent.left
                anchors.right: actions.left
                anchors.rightMargin: Tokens.spacing.small
                anchors.verticalCenter: parent.verticalCenter
                text: root.current
                readOnly: root.note?.scratch ?? true
                color: Colours.palette.m3onSurface
                font.family: Tokens.font.serif
                font.pixelSize: Tokens.font.title
                clip: true
                selectByMouse: true
                onAccepted: {
                    const to = text.replace(/[\/\\:*?"<>|]/g, " ").trim();
                    if (store.rename(root.current, to))
                        root.current = to;
                    else
                        text = Qt.binding(() => root.current);
                    root.focusEditor();
                }
                Keys.onPressed: event => root.keys(event)
            }

            Row {
                id: actions

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                IconButton {
                    icon: root.preview ? "edit" : "visibility"
                    size: 32
                    filled: root.preview
                    onClicked: {
                        root.preview = !root.preview;
                        if (!root.preview)
                            Qt.callLater(root.focusEditor);
                    }
                }

                IconButton {
                    visible: !(root.note?.scratch ?? true)
                    icon: "push_pin"
                    size: 32
                    filled: root.note?.pinned ?? false
                    onClicked: store.togglePin(root.current)
                }

                IconButton {
                    visible: !(root.note?.scratch ?? true)
                    icon: root.armed ? "delete_forever" : "delete"
                    size: 32
                    filled: root.armed
                    fillColour: Colours.palette.m3errorContainer
                    inkColour: Colours.palette.m3onErrorContainer
                    onClicked: root.removeCurrent()
                }
            }
        }

        Hairline {
            id: rule

            anchors.top: bar.bottom
            anchors.topMargin: Tokens.spacing.small
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Tokens.spacing.normal
            anchors.rightMargin: Tokens.spacing.normal
        }

        Scroller {
            id: flick

            anchors.top: rule.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Tokens.spacing.large
            contentHeight: root.preview ? rendered.contentHeight : edit.contentHeight
            clip: true

            function ensureVisible(r: rect): void {
                if (contentY >= r.y)
                    contentY = r.y;
                else if (contentY + height <= r.y + r.height)
                    contentY = r.y + r.height - height;
            }

            TextEdit {
                id: edit

                visible: !root.preview
                width: flick.width
                wrapMode: TextEdit.Wrap
                color: Colours.palette.m3onSurface
                selectionColor: Colours.palette.m3primary
                selectedTextColor: Colours.palette.m3onPrimary
                font.pixelSize: Tokens.font.row
                textFormat: TextEdit.PlainText
                onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)
                onTextChanged: {
                    if (root.loaded)
                        save.restart();
                }
                Keys.onPressed: event => root.keys(event)

                StyledText {
                    visible: edit.text === ""
                    text: root.note?.scratch ? "Dump anything here. It's kept as you type." : "Write anything. Markdown works (Ctrl+E to preview)."
                    color: Colours.palette.m3onSurfaceVariant
                    font.pixelSize: Tokens.font.row
                    font.italic: true
                }
            }

            // The Markdown, rendered (links open in your browser).
            TextEdit {
                id: rendered

                visible: root.preview
                width: flick.width
                readOnly: true
                wrapMode: TextEdit.Wrap
                textFormat: TextEdit.MarkdownText
                text: edit.text
                color: Colours.palette.m3onSurface
                selectionColor: Colours.palette.m3primary
                font.pixelSize: Tokens.font.row
                onLinkActivated: link => Qt.openUrlExternally(link)
                Keys.onPressed: event => root.keys(event)
            }
        }
    }
}
