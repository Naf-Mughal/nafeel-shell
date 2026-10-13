pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.components

// Settings → Bar: the bar studio (ROADMAP B6). A miniature of the screen:
// each edge's start, centre and end, and the four corners, holding the
// icons (filled) and panels (outlined) placed there. Move one by dragging
// it, or by clicking it and then where it goes; an icon put on Hidden is
// hidden (its panel stays where it was until it's placed). Click an edge
// for its shape and how it shows; the corners' owners are below. Every
// change is live on the desktop (a BarLayout draft): Save keeps it, Revert
// (or leaving Settings unsaved) walks back. Scriptable too: `qs ipc call bar …`.
Item {
    id: root

    // The edge whose settings show below the screen.
    property string selectedEdge: "left"
    // The chip picked to move by clicking ({ kind, id, icon, label }), or null.
    property var picked: null
    // The preset last applied (its chip shows selected until the next edit).
    property string preset: ""

    readonly property var edgeGloss: ({
            left: "左",
            top: "上",
            right: "右",
            bottom: "下"
        })
    readonly property var edgeName: ({
            left: "Left",
            top: "Top",
            right: "Right",
            bottom: "Bottom"
        })
    readonly property var regionName: ({
            start: "start",
            center: "centre",
            end: "end"
        })

    implicitHeight: page.implicitHeight

    // Leaving the studio with unsaved changes walks the desktop back.
    Component.onDestruction: BarLayout.revert()

    Connections {
        target: BarLayout

        function onDraftChanged(): void {
            if (BarLayout.draft === null)
                root.preset = "";
        }
    }

    function describe(at: var): string {
        if (!at)
            return "not placed";
        if (at.corner)
            return `${at.corner.replace(/([A-Z])/, " $1").toLowerCase()} corner`;
        return `${edgeName[at.edge]} edge · ${regionName[at.region]}`;
    }

    // A region's chips: its icons, then the panels placed there.
    function chipsAt(edge: string, region: string): var {
        const hidden = BarLayout.layout.hidden ?? [];
        return BarLayout.rawWidgets(edge, region).filter(id => !hidden.includes(id)).map(id => ({
                    kind: "icon",
                    id: id,
                    icon: BarLayout.catalogue[id]?.icon ?? "widgets",
                    label: BarLayout.catalogue[id]?.name ?? id
                })).concat(panelsAt(at => !at.corner && at.edge === edge && at.region === region));
    }

    // The panels whose place passes `test`: drawers, and the popouts whose
    // icon is hidden (a shown icon carries its panel).
    function panelsAt(test: var): var {
        const out = [];
        for (const p of BarLayout.panelList) {
            const at = BarLayout.panelAt(p.name);
            if (at && test(at))
                out.push({
                    kind: "panel",
                    id: p.name,
                    icon: p.icon,
                    label: p.label
                });
        }
        for (const id of (BarLayout.layout.hidden ?? [])) {
            const pop = BarLayout.catalogue[id]?.popout;
            const at = pop ? BarLayout.popoutPlace(pop) : null;
            if (at && test(at))
                out.push({
                    kind: "panel",
                    id: "bar:" + pop,
                    icon: BarLayout.catalogue[id].icon,
                    label: `${BarLayout.catalogue[id].name} panel`
                });
        }
        return out;
    }

    function placeOfChip(c: var): var {
        return c.kind === "icon" ? BarLayout.placeOf(c.id) : BarLayout.panelAt(c.id);
    }

    // Whether `c` can go to `at` (a corner takes panels only).
    function fits(c: var, at: var): bool {
        return !!c && !(at.corner && c.kind === "icon");
    }

    // Move a chip to a place (before the icon `before`, else last).
    function put(c: var, at: var, before: string): void {
        if (!fits(c, at))
            return;
        if (c.kind === "icon")
            BarLayout.moveWidget(c.id, at.edge, at.region, before === c.id ? "" : before);
        else
            BarLayout.placePanel(c.id, at);
        picked = null;
    }

    function hide(c: var): void {
        if (!c)
            return;
        if (c.kind === "icon")
            BarLayout.hideWidget(c.id);
        else
            BarLayout.placePanel(c.id, null);
        picked = null;
    }

    Column {
        id: page

        width: root.width
        spacing: Tokens.spacing.large

        // ── Presets, Save, Revert ──
        Sheet {
            width: parent.width
            title: "Layout"
            gloss: "布局"

            trailing: [
                IconButton {
                    icon: "undo"
                    enabled: BarLayout.dirty
                    opacity: enabled ? 1 : 0.38
                    onClicked: BarLayout.revert()
                },
                IconButton {
                    icon: "check"
                    filled: BarLayout.dirty
                    fillColour: Colours.palette.m3primary
                    inkColour: Colours.palette.m3onPrimary
                    enabled: BarLayout.dirty
                    opacity: enabled ? 1 : 0.38
                    onClicked: BarLayout.save()
                }
            ]

            Flow {
                width: parent.width
                spacing: Tokens.spacing.small

                Repeater {
                    model: [
                        {
                            value: "default",
                            icon: "view_sidebar",
                            label: "Default"
                        },
                        {
                            value: "top",
                            icon: "toolbar",
                            label: "Top bar"
                        },
                        {
                            value: "floating",
                            icon: "bubble_chart",
                            label: "Floating"
                        },
                        {
                            value: "hidden",
                            icon: "visibility_off",
                            label: "Autohide"
                        }
                    ]

                    Chip {
                        required property var modelData

                        icon: modelData.icon
                        text: modelData.label
                        selected: root.preset === modelData.value
                        onClicked: {
                            BarLayout.usePreset(modelData.value);
                            root.preset = modelData.value;
                        }
                    }
                }
            }

            StyledText {
                width: parent.width
                wrapMode: Text.WordWrap
                text: BarLayout.dirty ? "Unsaved: the desktop shows it live. Save keeps it; Revert or leaving Settings walks back." : "Drag an icon or a panel to move it, or click it and then where it goes."
                color: BarLayout.dirty ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                font.pixelSize: Tokens.font.small
            }
        }

        // ── The screen ──
        Sheet {
            width: parent.width
            title: "Screen"
            gloss: "屏幕"

            Item {
                id: mini

                readonly property real side: 72
                readonly property real across: 44

                width: parent.width
                height: Math.round(width * 0.6)

                // The desktop: what's picked, or how to use it.
                Surface {
                    x: mini.side
                    y: mini.across
                    width: mini.width - mini.side * 2
                    height: mini.height - mini.across * 2
                    level: 1
                    shape: "large"

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - Tokens.spacing.large * 2
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.picked ? root.picked.icon : "drag_pan"
                            size: 30
                            fill: root.picked ? 1 : 0
                            color: root.picked ? Colours.palette.m3primary : Colours.palette.m3outline
                        }

                        StyledText {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: root.picked ? root.picked.label : "Your screen"
                            font.pixelSize: Tokens.font.row
                            font.weight: Font.DemiBold
                        }

                        StyledText {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: root.picked ? `${root.describe(root.placeOfChip(root.picked))} · click where it goes${root.picked.kind === "icon" ? ", or Hidden" : ""}` : "Click an edge for its settings"
                            color: Colours.palette.m3onSurfaceVariant
                            font.pixelSize: Tokens.font.small
                        }
                    }
                }

                // Each edge: a band (click it for its settings) with three zones.
                Repeater {
                    model: BarLayout.edgeNames

                    Surface {
                        id: band

                        required property string modelData
                        readonly property bool vertical: modelData === "left" || modelData === "right"
                        readonly property bool selected: root.selectedEdge === modelData

                        x: modelData === "right" ? mini.width - mini.side : vertical ? 0 : mini.side
                        y: modelData === "bottom" ? mini.height - mini.across : vertical ? mini.across : 0
                        width: vertical ? mini.side : mini.width - mini.side * 2
                        height: vertical ? mini.height - mini.across * 2 : mini.across
                        role: selected ? "secondary" : "paper"
                        emphasis: selected ? "ghost" : "soft"
                        level: 0
                        shape: "small"
                        outlined: selected
                        interactive: true
                        onClicked: root.selectedEdge = modelData

                        Grid {
                            anchors.fill: parent
                            anchors.margins: 4
                            columns: band.vertical ? 1 : 3
                            spacing: 4

                            Repeater {
                                model: BarLayout.regionNames

                                Zone {
                                    required property string modelData

                                    width: band.vertical ? parent.width : (parent.width - 8) / 3
                                    height: band.vertical ? (parent.height - 8) / 3 : parent.height
                                    place: ({
                                            edge: band.modelData,
                                            region: modelData
                                        })
                                    chips: root.chipsAt(band.modelData, modelData)
                                }
                            }
                        }
                    }
                }

                // The corners: panels only.
                Repeater {
                    model: ["topLeft", "topRight", "bottomLeft", "bottomRight"]

                    Zone {
                        required property string modelData

                        x: modelData.endsWith("Right") ? mini.width - mini.side : 0
                        y: modelData.startsWith("bottom") ? mini.height - mini.across : 0
                        width: mini.side
                        height: mini.across
                        place: ({
                                corner: modelData
                            })
                        chips: root.panelsAt(at => at.corner === modelData)
                    }
                }
            }
        }

        // ── What's picked ──
        Surface {
            visible: root.picked !== null
            width: parent.width
            height: 64
            level: 2
            shape: "large"

            Row {
                anchors.fill: parent
                anchors.margins: Tokens.spacing.normal
                spacing: Tokens.spacing.normal

                Surface {
                    id: badge

                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    height: 40
                    role: root.picked?.kind === "panel" ? "tertiary" : "secondary"
                    emphasis: "soft"
                    shape: "small"

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: root.picked?.icon ?? ""
                        fill: 1
                        color: badge.ink
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 40 - actions.width - Tokens.spacing.normal * 2

                    StyledText {
                        width: parent.width
                        elide: Text.ElideRight
                        text: root.picked?.label ?? ""
                        font.weight: Font.DemiBold
                    }

                    StyledText {
                        width: parent.width
                        elide: Text.ElideRight
                        text: root.picked ? `${root.picked.kind === "panel" ? "Panel" : "Icon"} · ${root.describe(root.placeOfChip(root.picked))}` : ""
                        color: Colours.palette.m3onSurfaceVariant
                        font.pixelSize: Tokens.font.small
                    }
                }

                Row {
                    id: actions

                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.spacing.small

                    IconButton {
                        icon: root.picked?.kind === "panel" ? "restart_alt" : "visibility_off"
                        onClicked: root.hide(root.picked)
                    }

                    IconButton {
                        icon: "close"
                        onClicked: root.picked = null
                    }
                }
            }
        }

        // ── Hidden icons ──
        Sheet {
            width: parent.width
            title: "Hidden"
            gloss: "隐"

            Surface {
                id: hiddenTray

                readonly property var chips: (BarLayout.layout.hidden ?? []).filter(id => BarLayout.catalogue[id]).map(id => ({
                            kind: "icon",
                            id: id,
                            icon: BarLayout.catalogue[id].icon,
                            label: BarLayout.catalogue[id].name
                        }))
                readonly property bool target: hiddenDrop.containsDrag || root.picked !== null

                width: parent.width
                height: Math.max(56, hiddenFlow.implicitHeight + Tokens.spacing.normal * 2)
                role: target ? "primary" : "paper"
                emphasis: "ghost"
                level: 2
                shape: "normal"
                outlined: true
                interactive: root.picked !== null
                onClicked: root.hide(root.picked)

                StyledText {
                    anchors.centerIn: parent
                    visible: hiddenTray.chips.length === 0
                    text: root.picked ? (root.picked.kind === "icon" ? "Click to hide it" : "Click to put it back where it opens by default") : "Drop an icon here to hide it"
                    color: hiddenTray.subInk
                    font.pixelSize: Tokens.font.small
                }

                Flow {
                    id: hiddenFlow

                    anchors.fill: parent
                    anchors.margins: Tokens.spacing.normal
                    spacing: 4

                    Repeater {
                        model: hiddenTray.chips

                        StudioChip {
                            required property var modelData

                            info: modelData
                        }
                    }
                }

                DropArea {
                    id: hiddenDrop

                    function accept(c: var): void {
                        root.hide(c);
                    }

                    anchors.fill: parent
                }
            }
        }

        // ── The selected edge ──
        Sheet {
            width: parent.width
            title: `${root.edgeName[root.selectedEdge]} edge`
            gloss: root.edgeGloss[root.selectedEdge]

            SectionLabel {
                text: "Shape"
            }

            ButtonGroup {
                width: parent.width
                model: [
                    {
                        value: "full",
                        icon: "view_sidebar",
                        label: "Full bar"
                    },
                    {
                        value: "regions",
                        icon: "more_vert",
                        label: "Regions"
                    }
                ]
                current: BarLayout.mode(root.selectedEdge)
                onSelected: v => BarLayout.setEdge(root.selectedEdge, "mode", v)
            }

            SectionLabel {
                text: BarLayout.mode(root.selectedEdge) === "regions" ? "Shows, each region" : "Shows"
            }

            Repeater {
                model: BarLayout.mode(root.selectedEdge) === "regions" ? BarLayout.regionNames : [""]

                Row {
                    id: visRow

                    required property string modelData

                    width: parent.width
                    spacing: Tokens.spacing.normal

                    MicroLabel {
                        visible: visRow.modelData !== ""
                        width: 52
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.regionName[visRow.modelData] ?? ""
                    }

                    ButtonGroup {
                        width: parent.width - (visRow.modelData !== "" ? 52 + Tokens.spacing.normal : 0)
                        model: [
                            {
                                value: "reserve",
                                icon: "vertical_split",
                                label: "Reserve"
                            },
                            {
                                value: "overlay",
                                icon: "layers",
                                label: "Overlay"
                            },
                            {
                                value: "autohide",
                                icon: "visibility_off",
                                label: "Autohide"
                            }
                        ]
                        current: BarLayout.visibility(root.selectedEdge, visRow.modelData)
                        onSelected: v => visRow.modelData ? BarLayout.setRegionVisibility(root.selectedEdge, visRow.modelData, v) : BarLayout.setEdge(root.selectedEdge, "visibility", v)
                    }
                }
            }
        }

        // ── Corners ──
        Sheet {
            width: parent.width
            title: "Corners"
            gloss: "角"

            StyledText {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "A corner goes to the bar with something at that end. When both have, to:"
                color: Colours.palette.m3onSurfaceVariant
                font.pixelSize: Tokens.font.small
            }

            Repeater {
                model: [
                    {
                        corner: "topLeft",
                        label: "Top left",
                        side: "Left",
                        cross: "Top"
                    },
                    {
                        corner: "topRight",
                        label: "Top right",
                        side: "Right",
                        cross: "Top"
                    },
                    {
                        corner: "bottomLeft",
                        label: "Bottom left",
                        side: "Left",
                        cross: "Bottom"
                    },
                    {
                        corner: "bottomRight",
                        label: "Bottom right",
                        side: "Right",
                        cross: "Bottom"
                    }
                ]

                Row {
                    id: cornerRow

                    required property var modelData

                    width: parent.width
                    spacing: Tokens.spacing.normal

                    MicroLabel {
                        width: 84
                        anchors.verticalCenter: parent.verticalCenter
                        text: cornerRow.modelData.label
                    }

                    ButtonGroup {
                        width: parent.width - 84 - Tokens.spacing.normal
                        model: [
                            {
                                value: "vertical",
                                icon: "border_left",
                                label: cornerRow.modelData.side
                            },
                            {
                                value: "horizontal",
                                icon: "border_top",
                                label: cornerRow.modelData.cross
                            },
                            {
                                value: "none",
                                icon: "crop_free",
                                label: "Neither"
                            }
                        ]
                        current: BarLayout.layout.corners?.[cornerRow.modelData.corner] ?? "vertical"
                        onSelected: v => BarLayout.setCorner(cornerRow.modelData.corner, v)
                    }
                }
            }
        }
    }

    // Above everything: a chip's face while it's dragged.
    Item {
        id: overlay

        anchors.fill: parent
        z: 10
    }

    // A drop zone: an edge's region or a corner, holding its chips. With a
    // chip picked, clicking it moves the chip here.
    component Zone: Surface {
        id: zone

        required property var place
        property var chips: []
        readonly property bool target: (drop.containsDrag && root.fits(drop.drag.source?.info ?? null, place)) || (root.fits(root.picked, place) && hovered)

        role: target ? "primary" : "paper"
        emphasis: target ? "ghost" : "soft"
        level: place.corner ? 4 : 3
        shape: "small"
        outlined: true
        interactive: root.fits(root.picked, place)
        onClicked: root.put(root.picked, zone.place, "")

        DropArea {
            id: drop

            function accept(c: var): void {
                root.put(c, zone.place, "");
            }

            anchors.fill: parent
        }

        Flow {
            anchors.fill: parent
            anchors.margins: 3
            spacing: 3

            Repeater {
                model: zone.chips

                StudioChip {
                    required property var modelData

                    info: modelData
                    // Dropped on an icon: goes before it.
                    onDroppedOn: c => root.put(c, zone.place, modelData.kind === "icon" ? modelData.id : "")
                }
            }
        }
    }

    // An icon (filled) or a panel (outlined). Click to pick it; drag it (its
    // face floats over the studio, the page doesn't scroll) and let go on a
    // zone, on another icon (to go before it) or on Hidden.
    component StudioChip: Item {
        id: chip

        required property var info
        readonly property bool isPicked: root.picked !== null && root.picked.kind === info.kind && root.picked.id === info.id
        signal droppedOn(var info)

        width: 26
        height: 26

        DropArea {
            function accept(c: var): void {
                if (!(c.kind === chip.info.kind && c.id === chip.info.id))
                    chip.droppedOn(c);
            }

            anchors.fill: parent
        }

        Surface {
            id: face

            // What a drop reads.
            readonly property var info: chip.info

            width: chip.width
            height: chip.height
            role: chip.isPicked ? "primary" : chip.info.kind === "panel" ? "tertiary" : "secondary"
            emphasis: chip.isPicked ? "strong" : chip.info.kind === "panel" ? "ghost" : "soft"
            outlined: chip.info.kind === "panel" && !chip.isPicked
            shape: "small"
            scale: grab.drag.active ? 1.2 : grab.containsMouse ? 1.08 : 1

            Behavior on scale {
                Anim {
                    duration: Tokens.anim.fast
                }
            }

            Drag.active: grab.drag.active
            Drag.source: face
            Drag.hotSpot.x: width / 2
            Drag.hotSpot.y: height / 2

            MaterialIcon {
                anchors.centerIn: parent
                text: chip.info.icon
                size: 16
                fill: chip.info.kind === "panel" ? 0 : 1
                color: face.ink
            }
        }

        MouseArea {
            id: grab

            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            drag.target: face
            onPressed: {
                const p = face.mapToItem(overlay, 0, 0);
                face.parent = overlay;
                face.x = p.x;
                face.y = p.y;
            }
            // The drop target is read first and the face put back before the
            // move: the move remakes the chips, this one included.
            onReleased: {
                const dragged = drag.active;
                const target = face.Drag.target;
                const info = chip.info;
                face.parent = chip;
                face.x = 0;
                face.y = 0;
                if (!dragged)
                    root.picked = chip.isPicked ? null : info;
                else if (target && typeof target.accept === "function")
                    Qt.callLater(() => target.accept(info));
            }
            onCanceled: {
                face.parent = chip;
                face.x = 0;
                face.y = 0;
            }
        }
    }
}
