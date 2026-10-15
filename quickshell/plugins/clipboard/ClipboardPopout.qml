pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
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

    // The preview's file goes with the popout.
    Component.onDestruction: Clipboard.clearPreview()

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

    // Dragging a pin into a new place among the pins (their icon is the
    // grip; not while searching: the list is filtered then). The others
    // make room; on release it's moved (Clipboard.movePin).
    readonly property int pins: query.trim() === "" ? Clipboard.entries.filter(e => e.pinned).length : 0
    property int pinFrom: -1
    property int pinTo: -1
    property real pinY: 0
    readonly property real rowPitch: 48 + 2

    function pinSlot(i: int): int {
        if (pinFrom < 0 || i >= pins)
            return i;
        if (i === pinFrom)
            return pinTo;
        if (pinFrom < pinTo && i > pinFrom && i <= pinTo)
            return i - 1;
        if (pinFrom > pinTo && i >= pinTo && i < pinFrom)
            return i + 1;
        return i;
    }
    readonly property int index: shown[Math.min(sel, shown.length - 1)] ?? -1
    readonly property var entry: index >= 0 ? Clipboard.entries[index] : null
    // A destructive action waiting for its second press: "delete" | "clear".
    property string armed: ""

    function move(by: int): void {
        if (shown.length > 0)
            sel = Math.max(0, Math.min(shown.length - 1, sel + by));
        armed = "";
    }

    // Auto-paste: copied at once; the shortcut goes once the frame has let
    // go of the keyboard (a fixed wait sent it while the closing panel still
    // held it, ~0.5 s, so it pasted into the shell, not the app).
    property bool pastePending: false
    property bool pasteImage: false

    function paste(): void {
        if (index < 0)
            return;
        pasteImage = entry?.image ?? false;
        Clipboard.activate(index, false);
        pastePending = true;
        ShellState.close();
        if (ShellState.keyboardHeld)
            pasteFallback.restart();
        else
            pasteNow.restart();
    }

    function sendPaste(): void {
        pasteFallback.stop();
        if (!pastePending)
            return;
        pastePending = false;
        Clipboard.pasteShortcut(pasteImage);
    }

    Connections {
        target: ShellState

        function onKeyboardReleased(): void {
            if (root.pastePending)
                pasteNow.restart();
        }
    }

    // The app takes the keyboard back a moment after the release.
    Timer {
        id: pasteNow

        interval: 60
        onTriggered: root.sendPaste()
    }

    Timer {
        id: pasteFallback

        interval: 2000
        onTriggered: root.sendPaste()
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

            // The goo on the selected entry (it glides as the keys move it),
            // following the hover; in the list's content, under the rows.
            ListGoo {
                id: entriesGoo

                z: -1
                width: list.width
                height: list.contentHeight
                container: list.contentItem
            }

            delegate: Surface {
                id: row

                required property int modelData
                required property int index
                readonly property var e: Clipboard.entries[modelData] ?? ({})
                readonly property bool selected: index === root.sel
                // A goo row: the list's goo rests on the selected one and follows
                // the hover; the ink turns while it's under the row.
                property Item goo: entriesGoo
                readonly property bool picked: selected
                readonly property bool inked: entriesGoo.covers(row)

                // Making room for a pin being dragged, or riding the finger.
                readonly property bool lifted: root.pinFrom === index
                property real shift: lifted ? root.pinY - index * root.rowPitch : (root.pinSlot(index) - index) * root.rowPitch
                Behavior on shift {
                    enabled: !row.lifted && !Tokens.reduceMotion
                    SpringAnimation {
                        spring: Tokens.spring.control.spring
                        damping: Tokens.spring.control.damping
                        epsilon: 0.3
                    }
                }
                transform: Translate {
                    y: row.shift
                }
                z: lifted ? 10 : 0
                outlined: lifted

                width: list.width
                height: 48
                emphasis: "ghost"
                hoverLayer: false
                baseInk: inked ? Colours.roleInk("secondary", "soft") : Colours.roleInk("paper", "soft")
                baseSubInk: inked ? Colours.roleSubInk("secondary", "soft") : Colours.roleSubInk("paper", "soft")
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

                // The entry's kind (an image: its thumbnail), and for a pin
                // the grip it's dragged by.
                Item {
                    id: kind

                    anchors.left: parent.left
                    anchors.leftMargin: Tokens.spacing.small
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 36

                    ClippingRectangle {
                        anchors.fill: parent
                        visible: thumb.status === Image.Ready
                        radius: Tokens.rounding.small
                        color: "transparent"

                        Image {
                            id: thumb

                            anchors.fill: parent
                            // Made once per entry, as rows come into view (off
                            // the GUI thread: "" until it's ready).
                            source: {
                                Clipboard.thumbsRevision;
                                const f = row.e.image ? Clipboard.thumbFile(row.modelData) : "";
                                return f ? "file://" + f : "";
                            }
                            sourceSize: Qt.size(72, 72)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                        }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: thumb.status !== Image.Ready || row.e.pinned
                        text: row.e.pinned ? (pinHover.hovered || row.lifted ? "drag_indicator" : "push_pin") : row.e.image ? "image" : "notes"
                        fill: row.e.pinned ? 1 : 0
                        color: row.inked ? row.ink : row.subInk
                        size: 18

                        // Over a thumbnail, on a disc so it reads.
                        Rectangle {
                            visible: thumb.status === Image.Ready
                            z: -1
                            anchors.centerIn: parent
                            width: 22
                            height: 22
                            radius: 11
                            color: Qt.alpha(Colours.palette.m3surface, 0.75)
                        }
                    }

                    HoverHandler {
                        id: pinHover

                        enabled: row.index < root.pins
                        cursorShape: row.lifted ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    }

                    DragHandler {
                        enabled: row.index < root.pins && root.pins > 1
                        target: null
                        xAxis.enabled: false
                        property real startY: 0

                        onActiveChanged: {
                            if (active) {
                                startY = row.index * root.rowPitch;
                                root.pinY = startY;
                                root.pinTo = row.index;
                                root.pinFrom = row.index;
                            } else if (root.pinFrom >= 0) {
                                const from = root.pinFrom, to = root.pinTo;
                                root.pinFrom = -1;
                                root.pinTo = -1;
                                if (from !== to) {
                                    Clipboard.movePin(from, to);
                                    root.sel = to;
                                }
                            }
                        }
                        onTranslationChanged: {
                            if (!active)
                                return;
                            root.pinY = Math.max(0, Math.min((root.pins - 1) * root.rowPitch, startY + translation.y));
                            root.pinTo = Math.round(root.pinY / root.rowPitch);
                        }
                    }
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
                    // The text, loaded once per selection (its first 20 000
                    // characters: a huge paste would cost its size twice
                    // over to lay out; the copy itself stays whole).
                    text: root.entry && !root.entry.image ? Clipboard.text(root.index, 20000) : ""
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
                // From a private file (Clipboard.imageFile), decoded at its
                // size: no base64 copies of the payload.
                source: root.entry?.image ? (f => f ? "file://" + f : "")(Clipboard.imageFile(root.index)) : ""
                // At the size shown (a pasted screenshot is screen-sized).
                sourceSize: Qt.size(Math.max(64, Math.ceil(width * 2)), Math.max(64, Math.ceil(height * 2)))
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
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
