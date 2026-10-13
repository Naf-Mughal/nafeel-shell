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

    // Leaving the studio with unsaved changes walks the desktop back (not
    // when it handed them to the edit mode on the bar).
    Component.onDestruction: {
        if (!BarLayout.editing)
            BarLayout.revert();
    }

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

    function chipsAt(edge: string, region: string): var {
        return BarLayout.chipsAt(edge, region);
    }

    function panelsAt(test: var): var {
        return BarLayout.panelChips(test);
    }

    function placeOfChip(c: var): var {
        return c.kind === "icon" ? BarLayout.placeOf(c.id) : BarLayout.panelAt(c.id);
    }

    function isPicked(c: var): bool {
        return picked !== null && picked.kind === c.kind && picked.id === c.id;
    }

    function fits(c: var, at: var): bool {
        return BarLayout.fits(c, at);
    }

    function put(c: var, at: var, before: string): void {
        BarLayout.put(c, at, before);
        picked = null;
    }

    function hide(c: var): void {
        BarLayout.unplace(c);
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
                    icon: "edit"
                    onClicked: {
                        BarLayout.editing = true;
                        ShellState.close();
                    }
                },
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
                            icon: "side_navigation",
                            label: "Left bar"
                        },
                        {
                            value: "top",
                            icon: "web_asset",
                            label: "Top bar"
                        },
                        {
                            value: "bottom",
                            icon: "toolbar",
                            label: "Bottom bar"
                        },
                        {
                            value: "right",
                            icon: "view_sidebar",
                            label: "Right bar"
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
                text: BarLayout.dirty ? "Unsaved: the desktop shows it live. Save keeps it; Revert or leaving Settings walks back." : "Drag an icon or a panel to move it, or click it and then where it goes. ✎ edits on the bar itself (Mod+B)."
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

                // The bands' thickness: enough rows (top, bottom) or columns
                // (sides) for their fullest zone's chips (26 px, 3 apart, in
                // zones with a 3 px margin, in bands with 4).
                readonly property var bands: {
                    const pitch = 29;
                    const counts = {};
                    for (const e of BarLayout.edgeNames)
                        counts[e] = BarLayout.regionNames.map(r => root.chipsAt(e, r).length);
                    const fit = (len, n) => Math.ceil(n / Math.max(1, Math.floor((len - 6 + 3) / pitch)));
                    let side = 72, across = 44;
                    for (let i = 0; i < 2; i++) {
                        const zoneW = (width - side * 2 - 8 - 8) / 3;
                        const rows = Math.max(...counts.top.map(n => fit(zoneW, n)), ...counts.bottom.map(n => fit(zoneW, n)), 1);
                        across = Math.max(44, 8 + 6 + rows * pitch - 3);
                        const zoneH = (height - across * 2 - 8 - 8) / 3;
                        const cols = Math.max(...counts.left.map(n => fit(zoneH, n)), ...counts.right.map(n => fit(zoneH, n)), 1);
                        side = Math.max(72, 8 + 6 + cols * pitch - 3);
                    }
                    return {
                        side: side,
                        across: across
                    };
                }
                readonly property real side: bands.side
                readonly property real across: bands.across

                width: parent.width
                height: Math.round(width * 0.62)

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

                readonly property var chips: BarLayout.hiddenChips()
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

                        LayoutChip {
                            required property var modelData

                            info: modelData
                            overlay: dragLayer
                            isPicked: root.isPicked(modelData)
                            onPick: root.picked = isPicked ? null : modelData
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
                text: "Shows"
            }

            ButtonGroup {
                width: parent.width
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
                current: BarLayout.visibility(root.selectedEdge, "")
                onSelected: v => BarLayout.setEdge(root.selectedEdge, "visibility", v)
            }

            StyledText {
                width: parent.width
                wrapMode: Text.WordWrap
                text: ({
                        reserve: "Windows keep clear of the whole bar, even between its pills.",
                        overlay: "Windows go under the bar.",
                        autohide: "The thin strip until you hover it, open one of its panels, or the workspace is empty."
                    })[BarLayout.visibility(root.selectedEdge, "")]
                color: Colours.palette.m3onSurfaceVariant
                font.pixelSize: Tokens.font.small
            }

            // An overlay bar in regions mode: each region shown or autohidden.
            SectionLabel {
                visible: regionVis.visible
                text: "Each region"
            }

            Column {
                id: regionVis

                visible: BarLayout.mode(root.selectedEdge) === "regions" && BarLayout.visibility(root.selectedEdge, "") === "overlay"
                width: parent.width
                spacing: Tokens.spacing.small

                Repeater {
                    model: BarLayout.regionNames

                    Row {
                        id: visRow

                        required property string modelData

                        width: parent.width
                        spacing: Tokens.spacing.normal

                        MicroLabel {
                            width: 52
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.regionName[visRow.modelData]
                        }

                        ButtonGroup {
                            width: parent.width - 52 - Tokens.spacing.normal
                            model: [
                                {
                                    value: "overlay",
                                    icon: "visibility",
                                    label: "Show"
                                },
                                {
                                    value: "autohide",
                                    icon: "visibility_off",
                                    label: "Autohide"
                                }
                            ]
                            current: BarLayout.visibility(root.selectedEdge, visRow.modelData)
                            onSelected: v => BarLayout.setRegionVisibility(root.selectedEdge, visRow.modelData, v)
                        }
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
        id: dragLayer

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

                LayoutChip {
                    required property var modelData

                    info: modelData
                    overlay: dragLayer
                    isPicked: root.isPicked(modelData)
                    onPick: root.picked = isPicked ? null : modelData
                    // Dropped on an icon: goes before it.
                    onDroppedOn: c => root.put(c, zone.place, modelData.kind === "icon" ? modelData.id : "")
                }
            }
        }
    }
}
