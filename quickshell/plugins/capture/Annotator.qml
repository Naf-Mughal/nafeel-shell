pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Nafeel
import qs.config
import qs.services
import qs.components

// The annotator: an image (a region just picked, or a screenshot's "Edit")
// over the dimmed desktop on the focused screen, a toolbar beneath it. Tools
// and keys after Noctalia's annotator: M move, B brush, H highlighter, L line,
// A arrow, S rectangle, O circle, T text, N numbering, U blur, E eraser,
// C crop; [ ] size; Shift snaps; Ctrl+Z / Ctrl+Shift+Z or Ctrl+Y; Ctrl+C
// copies, Ctrl+S saves, Enter is done (saved to ~/Pictures/Screenshots and
// copied, as a screenshot is); Esc ends a drag, then drops the crop, then
// closes. Each tool keeps its own colour and size (annotate.json).
//
// capture.annotator is this; capture.annotate(path) opens it.
Scope {
    id: root

    // The capture service (the plugin's; set by Plugin.qml).
    required property var capture

    property bool active: false
    property string source: ""
    // The source is a temporary still (a region just picked): removed on close.
    property bool temporary: false

    readonly property var tools: [
        {
            name: "move",
            icon: "open_with",
            label: "Move",
            key: "M"
        },
        {
            name: "brush",
            icon: "brush",
            label: "Brush",
            key: "B"
        },
        {
            name: "highlighter",
            icon: "ink_highlighter",
            label: "Highlighter",
            key: "H"
        },
        {
            name: "line",
            icon: "horizontal_rule",
            label: "Line",
            key: "L"
        },
        {
            name: "arrow",
            icon: "arrow_outward",
            label: "Arrow",
            key: "A"
        },
        {
            name: "rectangle",
            icon: "rectangle",
            label: "Rectangle",
            key: "S"
        },
        {
            name: "circle",
            icon: "circle",
            label: "Circle",
            key: "O"
        },
        {
            name: "text",
            icon: "title",
            label: "Text",
            key: "T"
        },
        {
            name: "numbering",
            icon: "counter_1",
            label: "Numbering",
            key: "N"
        },
        {
            name: "blur",
            icon: "blur_on",
            label: "Blur",
            key: "U"
        },
        {
            name: "eraser",
            icon: "ink_eraser",
            label: "Eraser",
            key: "E"
        },
        {
            name: "crop",
            icon: "crop",
            label: "Crop",
            key: "C"
        }
    ]
    readonly property var swatches: ["#f53347", "#ffe833", "#33cc66", "#338cff", "#ff991a", "#b259f2", "#ffffff", "#000000"]
    readonly property var defaultWidths: ({
            highlighter: 24,
            eraser: 28,
            blur: 32,
            text: 24,
            numbering: 32
        })
    // S / M / L: the tool's own default times these.
    readonly property var presets: [0.5, 1, 2]

    // { tool, fill, colors: { tool: "#rrggbb" }, widths: { tool: px } }
    property var prefs: ({
            tool: "arrow",
            fill: false,
            colors: {},
            widths: {}
        })
    readonly property string tool: prefs.tool ?? "arrow"
    readonly property string toolColor: prefs.colors?.[tool] ?? swatches[0]
    readonly property real baseWidth: defaultWidths[tool] ?? 6
    readonly property real toolWidth: prefs.widths?.[tool] ?? baseWidth
    readonly property bool usesColor: tool !== "move" && tool !== "eraser" && tool !== "crop" && tool !== "blur"

    function open(path: string, temporary: bool): void {
        if (!path)
            return;
        if (active)
            close();
        root.temporary = temporary;
        root.source = path.startsWith("file://") ? path.slice(7) : path;
        root.active = true;
    }

    function close(): void {
        if (!active)
            return;
        active = false;
        if (temporary)
            Quickshell.execDetached(["rm", "-f", source]);
        source = "";
    }

    function setPref(key: string, value: var): void {
        const next = Object.assign({}, prefs);
        next[key] = value;
        prefs = next;
        prefsFile.setText(JSON.stringify(prefs, null, 2));
    }

    function setToolPref(map: string, value: var): void {
        const next = Object.assign({}, prefs[map] ?? {});
        next[tool] = value;
        setPref(map, next);
    }

    function setWidth(w: real): void {
        const text = tool === "text";
        setToolPref("widths", Math.max(text ? 8 : 1, Math.min(text ? 200 : 100, Math.round(w))));
    }

    Component.onCompleted: root.capture.annotator = root

    IpcHandler {
        target: "annotate"

        // An image file to annotate (kept: Done saves a new screenshot).
        function open(path: string): void {
            root.open(path, false);
        }

        // Pick a region, then annotate it.
        function region(): void {
            root.capture.request("annotate", "");
        }

        function close(): void {
            root.close();
        }
    }

    FileView {
        id: prefsFile

        path: root.capture.dir + "/annotate.json"
        printErrors: false
        onLoaded: {
            try {
                root.prefs = Object.assign({}, root.prefs, JSON.parse(text()));
            } catch (e) {}
        }
    }

    Variants {
        model: root.active ? Quickshell.screens.filter(s => s.name === Umbriel.focusedOutput || (Umbriel.focusedOutput === "" && s === Quickshell.screens[0])) : []

        PanelWindow {
            id: win

            required property ShellScreen modelData
            property string feedback: ""
            property string hint: ""

            function exportShot(done: bool): void {
                const path = root.capture.newShotPath();
                if (!canvas.save(path)) {
                    flash("Couldn't save");
                    return;
                }
                Clipboard.copyImageFile(path);
                Quickshell.execDetached([root.capture.bin + "/capture-notify", "shot", path, "copied"]);
                if (done)
                    root.close();
                else
                    flash("Saved and copied");
            }

            function copy(): void {
                const path = `${root.capture.dir}/annotate-copy.png`;
                if (canvas.save(path)) {
                    Clipboard.copyImageFile(path);
                    flash("Copied");
                } else {
                    flash("Couldn't copy");
                }
            }

            function flash(text: string): void {
                feedback = text;
                feedbackTimer.restart();
            }

            function goBack(): void {
                if (canvas.cancelGesture())
                    return;
                if (canvas.hasCrop)
                    canvas.clearCrop();
                else
                    root.close();
            }

            function toolKey(key: int): bool {
                const t = root.tools.find(t => t.key.charCodeAt(0) === key);
                if (!t)
                    return false;
                root.setPref("tool", t.name);
                return true;
            }

            screen: modelData
            anchors {
                left: true
                right: true
                top: true
                bottom: true
            }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "nafeel-shell-annotate"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            Timer {
                id: feedbackTimer

                interval: 1600
                onTriggered: win.feedback = ""
            }

            // The desktop, dimmed.
            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(Colours.palette.m3scrim, 0.72)
                opacity: canvas.imageSize.width > 0 ? 1 : 0

                Behavior on opacity {
                    Anim {
                        duration: Tokens.anim.normal
                    }
                }

                // A click off the image ends the text being typed.
                MouseArea {
                    anchors.fill: parent
                    onPressed: canvas.commitText()
                }
            }

            // The image, as large as fits above the toolbar (never enlarged).
            Item {
                id: stage

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: toolbar.top
                anchors.margins: Tokens.spacing.large * 3
                anchors.bottomMargin: Tokens.spacing.large

                readonly property real fit: canvas.imageSize.width > 0 ? Math.min(1, width / canvas.imageSize.width, height / canvas.imageSize.height) : 1

                // A hairline round the paper it's drawn on.
                Rectangle {
                    anchors.fill: canvas
                    anchors.margins: -Tokens.hairline
                    color: "transparent"
                    border.width: Tokens.hairline
                    border.color: Qt.alpha(Colours.palette.m3onSurface, 0.25)
                }

                AnnotationCanvas {
                    id: canvas

                    anchors.centerIn: parent
                    width: Math.round(imageSize.width * stage.fit)
                    height: Math.round(imageSize.height * stage.fit)
                    source: root.source
                    tool: root.tool
                    color: root.toolColor
                    strokeWidth: root.toolWidth
                    fill: root.prefs.fill ?? false
                    fontFamily: Tokens.font.serif
                    accent: Colours.palette.m3primary
                    focus: true
                    // The canvas takes the keys first while text is typed.
                    Keys.priority: Keys.AfterItem
                    Keys.onPressed: event => {
                        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
                        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
                        event.accepted = true;
                        if (event.key === Qt.Key_Escape)
                            win.goBack();
                        else if (ctrl && event.key === Qt.Key_Z)
                            shift ? canvas.redo() : canvas.undo();
                        else if (ctrl && event.key === Qt.Key_Y)
                            canvas.redo();
                        else if (ctrl && event.key === Qt.Key_C)
                            win.copy();
                        else if (ctrl && event.key === Qt.Key_S)
                            win.exportShot(false);
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                            win.exportShot(true);
                        else if (event.key === Qt.Key_BracketLeft)
                            root.setWidth(root.toolWidth - 1);
                        else if (event.key === Qt.Key_BracketRight)
                            root.setWidth(root.toolWidth + 1);
                        else if (ctrl || (event.modifiers & (Qt.AltModifier | Qt.MetaModifier)) || !win.toolKey(event.key))
                            event.accepted = false;
                    }
                    Component.onCompleted: forceActiveFocus()
                }
            }

            // What a button does, or what just happened, over the toolbar.
            MicroLabel {
                anchors.horizontalCenter: toolbar.horizontalCenter
                anchors.bottom: toolbar.top
                anchors.bottomMargin: Tokens.spacing.small
                text: win.feedback || win.hint || (canvas.editingText ? "typing · enter keeps · esc drops" : `${root.tools.find(t => t.name === root.tool)?.label ?? ""} · shift snaps`)
                color: win.feedback ? Colours.palette.m3primary : Colours.palette.m3outline
            }

            // The toolbar: history, tools, fill, colours, size, export.
            Surface {
                id: toolbar

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Tokens.spacing.large * 2
                width: bar.implicitWidth + Tokens.spacing.normal * 2
                height: 56
                role: "paper"
                level: 2
                shape: "large"
                outlined: true

                Row {
                    id: bar

                    anchors.centerIn: parent
                    spacing: Tokens.spacing.tiny

                    ToolButton {
                        icon: "undo"
                        tip: "Undo · Ctrl+Z"
                        enabled: canvas.canUndo
                        onClicked: canvas.undo()
                    }
                    ToolButton {
                        icon: "redo"
                        tip: "Redo · Ctrl+Shift+Z"
                        enabled: canvas.canRedo
                        onClicked: canvas.redo()
                    }

                    Rule {}

                    Repeater {
                        model: root.tools

                        ToolButton {
                            required property var modelData

                            icon: modelData.icon
                            tip: `${modelData.label} · ${modelData.key}`
                            on: root.tool === modelData.name
                            onClicked: root.setPref("tool", modelData.name)
                        }
                    }

                    Rule {}

                    ToolButton {
                        icon: "format_color_fill"
                        tip: root.prefs.fill ? "Fill shapes: on" : "Fill shapes: off"
                        on: root.prefs.fill ?? false
                        enabled: root.tool === "rectangle" || root.tool === "circle"
                        onClicked: root.setPref("fill", !(root.prefs.fill ?? false))
                    }

                    Rule {}

                    // Colours: the tool's own; dots, so full rounds.
                    Repeater {
                        model: root.swatches

                        Item {
                            id: sw

                            required property string modelData
                            readonly property bool on: root.toolColor.toLowerCase() === modelData

                            anchors.verticalCenter: parent.verticalCenter
                            width: 26
                            height: 40
                            opacity: root.usesColor ? 1 : 0.35

                            Rectangle {
                                anchors.centerIn: parent
                                width: sw.on ? 22 : 18
                                height: width
                                radius: width / 2
                                color: sw.modelData
                                border.width: sw.on ? 2 : Tokens.hairline
                                border.color: sw.on ? Colours.palette.m3onSurface : Qt.alpha(Colours.palette.m3onSurface, 0.3)

                                Behavior on width {
                                    Anim {
                                        duration: Tokens.anim.fast
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: root.usesColor
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setToolPref("colors", sw.modelData)
                                onContainsMouseChanged: win.hint = containsMouse ? "Colour" : ""
                            }
                        }
                    }

                    Rule {}

                    // Size: S / M / L of the tool's own default, then finer.
                    Repeater {
                        model: ["S", "M", "L"]

                        ToolButton {
                            required property string modelData
                            required property int index

                            text: modelData
                            tip: "Size · [ ]"
                            enabled: root.tool !== "move" && root.tool !== "crop"
                            on: Math.abs(root.toolWidth - root.baseWidth * root.presets[index]) < 0.5
                            onClicked: root.setWidth(root.baseWidth * root.presets[index])
                        }
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        horizontalAlignment: Text.AlignHCenter
                        text: Math.round(root.toolWidth)
                        color: Colours.palette.m3onSurfaceVariant
                        font.family: Tokens.font.mono
                        font.pixelSize: Tokens.font.small
                    }

                    Rule {}

                    ToolButton {
                        icon: "content_copy"
                        tip: "Copy · Ctrl+C"
                        onClicked: win.copy()
                    }
                    ToolButton {
                        icon: "save"
                        tip: "Save and copy · Ctrl+S"
                        onClicked: win.exportShot(false)
                    }
                    ToolButton {
                        icon: "check"
                        tip: "Done: save, copy and close · Enter"
                        primary: true
                        onClicked: win.exportShot(true)
                    }
                    ToolButton {
                        icon: "close"
                        tip: "Close · Esc"
                        onClicked: root.close()
                    }
                }
            }

            component Rule: Hairline {
                anchors.verticalCenter: parent.verticalCenter
                vertical: true
                height: 24
            }

            // A toolbar button: the panels' Surface, on the shell's rounding;
            // the selected tool fills in the secondary role.
            component ToolButton: Surface {
                id: btn

                property string icon: ""
                property string text: ""
                property string tip: ""
                property bool on: false
                property bool primary: false

                anchors.verticalCenter: parent.verticalCenter
                width: 40
                height: 40
                role: primary ? "primary" : on ? "secondary" : "paper"
                emphasis: primary || on ? "strong" : "soft"
                level: 3
                interactive: enabled
                opacity: enabled ? 1 : 0.38
                onHoveredChanged: win.hint = hovered ? tip : ""

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: btn.icon !== ""
                    text: btn.icon
                    fill: btn.on || btn.primary ? 1 : 0
                    color: btn.ink
                    size: 20
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: btn.text !== ""
                    text: btn.text
                    color: btn.ink
                    font.family: Tokens.font.mono
                    font.pixelSize: Tokens.font.small
                    font.weight: Font.DemiBold
                }
            }
        }
    }
}
