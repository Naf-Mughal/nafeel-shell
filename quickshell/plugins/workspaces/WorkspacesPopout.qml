pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Nafeel
import qs.config
import qs.services
import qs.components
import "../../components/hosts.js" as Hosts

// Workspace previews: a card per workspace on the focused screen. The active
// one is a live view of the screen; the others are miniatures with each
// window at its real place and size, live (WindowThumb, a few frames a
// second). Click a card to switch, a window to focus it; drag a window
// onto another card to move it there (you stay where you are).
Column {
    id: root

    // A window being dragged to another workspace: what, where the pointer
    // is (in the panel), and the card it's over.
    property var dragging: null
    property point dragAt: Qt.point(0, 0)
    property int dropOn: -1
    readonly property Item host: Hosts.of(root)

    function cardAt(p: point): int {
        for (let i = 0; i < cards.count; i++) {
            const c = cards.itemAt(i);
            const r = c?.mapToItem(host, 0, 0, c.width, c.height);
            if (r && p.x >= r.x && p.x < r.x + r.width && p.y >= r.y && p.y < r.y + r.height)
                return i;
        }
        return -1;
    }

    function drop(): void {
        const w = dragging, i = dropOn;
        dragging = null;
        dropOn = -1;
        const target = i >= 0 ? root.spaces[i] : null;
        if (!w || !target || w.workspace === target.id)
            return;
        const back = root.spaces.find(s => s.active);
        // umbriel moves the focused window: focus it, send it, come back.
        Umbriel.dispatch("window-focus:" + w.id);
        Umbriel.dispatch(`window-move-to-workspace-silent:${target.name}/${root.output}`);
        if (back)
            Umbriel.dispatch(`workspace-switch:${back.name}/${root.output}`);
    }

    // The window on its way, riding the pointer (over the cards, which clip).
    Surface {
        parent: root.host
        z: 1000
        visible: root.dragging !== null
        x: root.dragAt.x - width / 2
        y: root.dragAt.y - height / 2
        width: 56
        height: 56
        level: 4
        outlined: true

        IconImage {
            anchors.centerIn: parent
            implicitSize: 30
            source: root.dragging ? Apps.icon(root.dragging.app_id) : ""
        }
    }

    readonly property string output: Umbriel.focusedOutput
    readonly property ShellScreen screen: Quickshell.screens.find(s => s.name === output) ?? Quickshell.screens[0] ?? null
    readonly property var spaces: Umbriel.workspacesOn(output)

    // Still for a moment (nothing moving or about to): the live window
    // captures run only then. Read straight off ShellState, a capture
    // slipped in between the grab ending and the springs starting, and its
    // first frame landed on the open's fourth refresh.
    readonly property bool quiet: ShellState.moving === 0 && ShellState.grabbing === ""
    property bool calm: false
    onQuietChanged: {
        if (quiet) {
            calmTimer.restart();
        } else {
            calmTimer.stop();
            calm = false;
        }
    }
    Timer {
        id: calmTimer

        interval: 150
        onTriggered: root.calm = root.quiet
    }
    readonly property real aspect: screen ? screen.height / screen.width : 9 / 16
    readonly property int columns: 2
    readonly property real cardWidth: (width - Tokens.spacing.normal * (columns - 1)) / columns

    spacing: Tokens.spacing.normal

    Item {
        width: parent.width
        height: 40

        GlossTitle {
            anchors.verticalCenter: parent.verticalCenter
            text: "Workspaces"
            gloss: Xian.gloss.workspaces
            size: Tokens.font.value
        }

        MicroLabel {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: `${root.spaces.filter(w => w.occupied).length} of ${root.spaces.length} in use`
        }
    }

    Grid {
        width: parent.width
        columns: root.columns
        spacing: Tokens.spacing.normal

        Repeater {
            id: cards

            // Diffed (ScriptModel, by id): umbriel sends every list again at
            // any focus change (the shell's own keyboard grab as this opens
            // included), and a new array rebuilt every card and restarted
            // its live window captures on the open's first frames.
            model: ScriptModel {
                values: root.spaces
                objectProp: "id"
            }

            Column {
                id: card

                required property var modelData
                required property int index
                readonly property bool active: modelData.active
                readonly property var windows: Umbriel.windowsOn(modelData.id)

                width: root.cardWidth
                spacing: Tokens.spacing.small

                ClippingRectangle {
                    id: frame

                    width: parent.width
                    height: Math.round(width * root.aspect)
                    radius: Tokens.rounding.normal
                    color: Colours.palette.m3surfaceContainerLow
                    // A window dragged over it: lit as where it'll go.
                    readonly property bool target: root.dragging !== null && root.dropOn === card.index && root.dragging.workspace !== card.modelData.id
                    border.width: card.active || target ? 2 : 1
                    border.color: target ? Colours.palette.m3tertiary : card.active ? Colours.palette.m3primary : cardHover.hovered ? Colours.palette.m3outline : Qt.alpha(Colours.palette.m3onSurface, 0.13)

                    // The active workspace: captured as the popout opens and
                    // twice a second while it's open; never while it closes (a
                    // live capture recorded its own exit, each frame landing
                    // between the display's refreshes, and kept a full-screen
                    // capture running at 60 fps behind it).
                    ScreencopyView {
                        id: shot

                        readonly property bool open: ShellState.pinned === "bar:workspaces" || ShellState.previewed === "bar:workspaces" || ShellState.grabbing === "bar:workspaces"

                        anchors.fill: parent
                        visible: card.active && root.screen !== null
                        // Not tied to the popout showing: setting a source
                        // takes a capture at once, and on every open its
                        // import landed on the motion's fourth frame.
                        captureSource: card.active ? root.screen : null
                        live: false

                        Timer {
                            running: shot.open && card.active && shot.captureSource !== null && ShellState.moving === 0 && ShellState.grabbing === ""
                            // Once it's out and still, then twice a second:
                            // the full-screen capture's import (a GPU device
                            // and texture) landed on the open's fourth frame,
                            // every time. The motion shows the last capture.
                            interval: 700
                            repeat: true
                            triggeredOnStart: true
                            onTriggered: shot.captureFrame()
                        }
                    }

                    // The others: a miniature of the desktop (the wallpaper in the
                    // shell's frame), their windows on it as live tiles.
                    Item {
                        id: desk

                        readonly property real k: width / (root.screen?.width ?? 1920)
                        // The frame's hole, scaled.
                        readonly property rect hole: Qt.rect(Tokens.barWidth * k, Tokens.border * k, width - (Tokens.barWidth + Tokens.border) * k, height - Tokens.border * 2 * k)

                        anchors.fill: parent
                        visible: !card.active

                        Image {
                            anchors.fill: parent
                            source: Session.wallpaper ? "file://" + Session.wallpaper : ""
                            // One size for every card, so they share one decoded copy.
                            sourceSize: Qt.size(Math.round(root.cardWidth), Math.round(root.cardWidth * root.aspect))
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }

                        // The frame: a border as thick as the bar around the
                        // hole, its inner edge rounded like the real one (the
                        // overflow is clipped by the card).
                        Rectangle {
                            readonly property real t: Tokens.barWidth * desk.k

                            x: desk.hole.x - t
                            y: desk.hole.y - t
                            width: desk.hole.width + t * 2
                            height: desk.hole.height + t * 2
                            radius: Tokens.frameRounding * desk.k + t
                            color: "transparent"
                            border.width: t
                            border.color: Colours.tPalette.m3surface
                        }

                        // Its gilded edge.
                        Rectangle {
                            x: desk.hole.x
                            y: desk.hole.y
                            width: desk.hole.width
                            height: desk.hole.height
                            radius: Tokens.frameRounding * desk.k
                            color: "transparent"
                            border.width: 1
                            border.color: Qt.alpha(Colours.palette.m3primary, 0.35)
                        }
                    }

                    // On the active card they're there only to be dragged (the
                    // live view shows the windows).
                    Item {
                        id: tiles

                        anchors.fill: parent

                        Repeater {
                            model: ScriptModel {
                                values: card.windows
                                objectProp: "id"
                            }

                            ClippingRectangle {
                                id: tile

                                required property var modelData
                                readonly property real sx: tiles.width / (root.screen?.width ?? 1920)
                                readonly property real sy: tiles.height / (root.screen?.height ?? 1080)

                                x: Math.max(0, modelData.x * sx)
                                y: Math.max(0, modelData.y * sy)
                                width: Math.min(tiles.width - x, modelData.w * sx)
                                height: Math.min(tiles.height - y, modelData.h * sy)
                                visible: width > 4 && height > 4
                                opacity: card.active ? 0 : root.dragging?.id === modelData.id ? 0.35 : 1
                                radius: Tokens.rounding.small / 2
                                color: Colours.palette.m3surfaceContainerHighest
                                border.width: 1
                                border.color: Qt.alpha(Colours.palette.m3onSurface, 0.13)

                                IconImage {
                                    anchors.centerIn: parent
                                    implicitSize: Math.max(12, Math.min(28, Math.min(tile.width, tile.height) * 0.45))
                                    source: Apps.icon(tile.modelData.app_id)
                                    visible: !thumb.ready
                                }

                                WindowThumb {
                                    id: thumb

                                    anchors.fill: parent
                                    windowId: tile.modelData.id
                                    crop: true
                                    fps: 4
                                    // Captures wait while a panel moves (this
                                    // one opening): the last frame shows.
                                    hold: !root.calm
                                }

                                StateLayer {
                                    hovered: tileHover.hovered
                                    ink: Colours.palette.m3onSurface
                                }

                                HoverHandler {
                                    id: tileHover

                                    cursorShape: Qt.PointingHandCursor
                                }

                                TapHandler {
                                    onTapped: {
                                        ShellState.close();
                                        Umbriel.dispatch("window-focus:" + tile.modelData.id);
                                    }
                                }

                                // Drag it onto another card to move it there.
                                DragHandler {
                                    target: null
                                    onActiveChanged: {
                                        if (active) {
                                            root.dragging = tile.modelData;
                                        } else if (root.dragging) {
                                            root.drop();
                                        }
                                    }
                                    onCentroidChanged: {
                                        if (!active || !root.host)
                                            return;
                                        root.dragAt = tile.mapToItem(root.host, centroid.position.x, centroid.position.y);
                                        root.dropOn = root.cardAt(root.dragAt);
                                    }
                                }
                            }
                        }

                        // Nothing open: 空 on a chip of the shell's surface.
                        StyledRect {
                            x: desk.hole.x + (desk.hole.width - width) / 2
                            y: desk.hole.y + (desk.hole.height - height) / 2
                            visible: card.windows.length === 0
                            width: 40
                            height: 40
                            radius: Tokens.rounding.normal
                            color: Colours.tPalette.m3surface

                            StyledText {
                                anchors.centerIn: parent
                                text: "空"
                                color: Colours.palette.m3onSurfaceVariant
                                font.family: Tokens.font.cjk
                                font.pixelSize: 20
                            }
                        }
                    }

                    // The workspace's numeral, sealed in the corner.
                    StyledRect {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: Tokens.spacing.small
                        width: 26
                        height: 26
                        radius: Tokens.rounding.small
                        color: card.active ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3surface, 0.85)

                        StyledText {
                            anchors.centerIn: parent
                            text: Xian.numeral(card.modelData.index)
                            color: card.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                            font.family: Tokens.font.cjk
                            font.pixelSize: 15
                            font.weight: Font.Bold
                        }
                    }

                    HoverHandler {
                        id: cardHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: {
                            ShellState.close();
                            Umbriel.dispatch(`workspace-switch:${card.modelData.name}/${root.output}`);
                        }
                    }
                }

                // The windows on it, by name.
                StyledText {
                    width: parent.width
                    text: card.windows.length === 0 ? "Empty" : card.windows.map(w => Apps.forAppId(w.app_id)?.name ?? w.app_id).filter((n, i, a) => a.indexOf(n) === i).join(" · ")
                    color: card.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                    font.pixelSize: Tokens.font.small
                    elide: Text.ElideRight
                }
            }
        }
    }
}
