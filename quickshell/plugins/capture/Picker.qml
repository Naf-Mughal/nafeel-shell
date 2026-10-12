pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// The capture region picker, as Noctalia's: every screen frozen (a still of
// it), dimmed outside the selection; drag a region, let go and it's taken (no
// confirm step). A click without a drag takes that whole screen. Esc or a
// right click cancels.
//
// capture.picker is this; capture.pick(purpose) shows it:
//   purpose "shot"    the selection is cut out of the still and saved
//                     (capture.shotTaken(path))
//   purpose "record"  the selection is handed back (capture.recordRegion)
//   purpose "annotate" the selection is cut out and opened in the annotator
//   purpose "screen"  no picking: the focused screen's still is saved at once
Scope {
    id: root

    // The capture service (the plugin's; set by Plugin.qml).
    required property var capture

    property bool active: false
    property string purpose: "shot"

    function begin(purpose: string): void {
        root.purpose = purpose;
        root.active = true;
    }

    function cancel(): void {
        root.active = false;
        root.capture.pickCancelled(root.purpose);
    }

    Component.onCompleted: root.capture.picker = root

    Variants {
        model: root.active ? Quickshell.screens : []

        PanelWindow {
            id: win

            required property ShellScreen modelData
            readonly property bool focusedScreen: modelData.name === Umbriel.focusedOutput || Umbriel.focusedOutput === ""
            property point from: Qt.point(0, 0)
            property point to: Qt.point(0, 0)
            property bool dragging: false
            readonly property rect sel: Qt.rect(Math.min(from.x, to.x), Math.min(from.y, to.y), Math.abs(to.x - from.x), Math.abs(to.y - from.y))
            property bool done: false

            // Save `area` of the still (in window coordinates) as a PNG.
            function save(area: rect): void {
                if (done)
                    return;
                done = true;
                crop.sourceRect = area;
                crop.x = area.x;
                crop.y = area.y;
                crop.width = area.width;
                crop.height = area.height;
                crop.visible = true;
                const dpr = win.modelData.devicePixelRatio || 1;
                const annotate = root.purpose === "annotate";
                const path = annotate ? root.capture.newAnnotatePath() : root.capture.newShotPath();
                Qt.callLater(() => crop.grabToImage(r => {
                        r.saveToFile(path);
                        root.active = false;
                        if (annotate)
                            root.capture.annotate(path, true);
                        else
                            root.capture.shotTaken(path);
                    }, Qt.size(Math.round(area.width * dpr), Math.round(area.height * dpr))));
            }

            function finish(area: rect): void {
                if (root.purpose === "record") {
                    root.active = false;
                    // Screen coordinates for the recorder (outputs at their position).
                    root.capture.recordRegion(win.modelData.name, Qt.rect(area.x + win.modelData.x, area.y + win.modelData.y, area.width, area.height));
                } else {
                    save(area);
                }
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
            WlrLayershell.namespace: "nafeel-shell-picker"
            WlrLayershell.keyboardFocus: focusedScreen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            // The still.
            ScreencopyView {
                id: still

                anchors.fill: parent
                captureSource: win.modelData
                live: false
                onHasContentChanged: {
                    // "screen": nothing to pick, save the focused screen now.
                    if (hasContent && root.purpose === "screen" && win.focusedScreen)
                        win.save(Qt.rect(0, 0, win.width, win.height));
                }
            }

            // The selection cut out of the still (what gets saved).
            ShaderEffectSource {
                id: crop

                visible: false
                sourceItem: still
                live: false
            }

            // Dim everything but the selection.
            Item {
                anchors.fill: parent
                // Only once the still is taken (it mustn't catch the dimming).
                visible: still.hasContent && root.purpose !== "screen"

                readonly property color shade: Qt.alpha(Colours.palette.m3shadow, 0.45)

                Rectangle {
                    width: parent.width
                    height: win.sel.y
                    color: parent.shade
                }
                Rectangle {
                    y: win.sel.y + win.sel.height
                    width: parent.width
                    height: parent.height - y
                    color: parent.shade
                }
                Rectangle {
                    y: win.sel.y
                    width: win.sel.x
                    height: win.sel.height
                    color: parent.shade
                }
                Rectangle {
                    x: win.sel.x + win.sel.width
                    y: win.sel.y
                    width: parent.width - x
                    height: win.sel.height
                    color: parent.shade
                }

                // The selection's edge and its size.
                Rectangle {
                    visible: win.dragging
                    x: win.sel.x - 1
                    y: win.sel.y - 1
                    width: win.sel.width + 2
                    height: win.sel.height + 2
                    color: "transparent"
                    border.width: 2
                    border.color: Colours.palette.m3primary
                }

                Rectangle {
                    visible: win.dragging && win.sel.width > 40
                    x: win.sel.x
                    y: win.sel.y + win.sel.height + 8 + height > parent.height ? win.sel.y - height - 8 : win.sel.y + win.sel.height + 8
                    width: size.implicitWidth + 16
                    height: size.implicitHeight + 8
                    radius: Tokens.rounding.small
                    color: Colours.palette.m3primary

                    Text {
                        id: size

                        anchors.centerIn: parent
                        text: `${Math.round(win.sel.width)} × ${Math.round(win.sel.height)}`
                        color: Colours.palette.m3onPrimary
                        font.family: Tokens.font.mono
                        font.pixelSize: Tokens.font.small
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.purpose !== "screen"
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.CrossCursor
                onPressed: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        root.cancel();
                        return;
                    }
                    win.from = Qt.point(mouse.x, mouse.y);
                    win.to = win.from;
                    win.dragging = true;
                }
                onPositionChanged: mouse => {
                    if (win.dragging)
                        win.to = Qt.point(mouse.x, mouse.y);
                }
                onReleased: mouse => {
                    if (mouse.button !== Qt.LeftButton || !win.dragging)
                        return;
                    win.dragging = false;
                    if (win.sel.width >= 2 && win.sel.height >= 2)
                        win.finish(win.sel);
                    else
                        // A click: the whole screen.
                        win.finish(Qt.rect(0, 0, win.width, win.height));
                }
            }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: root.cancel()
                Component.onCompleted: forceActiveFocus()
            }
        }
    }
}
