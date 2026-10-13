pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.components

// Settings → Bar: the bar studio (ROADMAP B6). A miniature of the screen
// with a drop zone for each edge's start, centre and end and each corner;
// icons (filled chips) and panels (outlined chips) are dragged between
// them, an icon dropped on "Hidden" is hidden (its panel stays where it was
// until placed). Click an edge to set its mode and how it shows; the
// corners' owners are set below. Every change is live on the desktop (a
// BarLayout draft); Save keeps it, Revert, or closing Settings unsaved,
// walks back.
Column {
    id: root

    // The edge whose settings show below the miniature.
    property string selectedEdge: "left"
    // The chip under the pointer, named in the status line.
    property string hoverText: ""

    spacing: Tokens.spacing.large

    // Closing the studio with unsaved changes walks the desktop back.
    Component.onDestruction: BarLayout.revert()

    readonly property var edgeLabels: ({
            left: "Left",
            top: "Top",
            right: "Right",
            bottom: "Bottom"
        })

    // A region's chips: its icons, then the panels placed there.
    function chipsAt(edge: string, region: string): var {
        const out = BarLayout.rawWidgets(edge, region).filter(id => !(BarLayout.layout.hidden ?? []).includes(id)).map(id => ({
                    kind: "widget",
                    id: id,
                    icon: BarLayout.catalogue[id]?.icon ?? "widgets",
                    label: BarLayout.catalogue[id]?.name ?? id
                }));
        return out.concat(panelsAt(p => !p.corner && p.edge === edge && p.region === region));
    }

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
        // Popouts whose icon is hidden: placed on their own.
        for (const id of (BarLayout.layout.hidden ?? [])) {
            const pop = BarLayout.catalogue[id]?.popout;
            if (!pop)
                continue;
            const at = BarLayout.popoutPlace(pop);
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

    // What a drop on a place does.
    function dropAt(data: var, at: var, before: string): void {
        if (!data)
            return;
        if (data.kind === "widget") {
            if (at.corner)
                return; // icons go on bars; a corner takes panels
            BarLayout.moveWidget(data.id, at.edge, at.region, before === data.id ? "" : before);
        } else {
            BarLayout.placePanel(data.id, at);
        }
    }

    // ── Presets, Save, Revert ──
    Row {
        width: parent.width
        spacing: Tokens.spacing.normal

        ButtonGroup {
            width: parent.width - actions.width - Tokens.spacing.normal
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
            current: ""
            onSelected: v => BarLayout.usePreset(v)
        }

        Row {
            id: actions

            spacing: Tokens.spacing.small

            ActionButton {
                text: "Revert"
                icon: "undo"
                enabled: BarLayout.dirty
                onClicked: BarLayout.revert()
            }

            ActionButton {
                text: "Save"
                icon: "check"
                primary: true
                enabled: BarLayout.dirty
                onClicked: BarLayout.save()
            }
        }
    }

    // ── The miniature ──
    Item {
        id: mini

        readonly property real band: 46
        readonly property real cornerSize: band

        width: parent.width
        height: Math.round(width * 0.56)

        // The desktop.
        Surface {
            anchors.fill: parent
            anchors.margins: mini.band
            level: 1
            shape: "small"

            Column {
                anchors.centerIn: parent
                width: parent.width - Tokens.spacing.large * 2
                spacing: Tokens.spacing.small

                MaterialIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "drag_pan"
                    size: 28
                    color: Colours.palette.m3outline
                }

                StyledText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: root.hoverText || "Drag icons and panels between the edges and corners. Click an edge for its settings."
                    color: Colours.palette.m3onSurfaceVariant
                    font.pixelSize: Tokens.font.small
                }

                MicroLabel {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: BarLayout.dirty
                    text: "unsaved · live on the desktop"
                    color: Colours.palette.m3primary
                }
            }
        }

        // Each edge's band (click to select) with its three zones.
        Repeater {
            model: BarLayout.edgeNames

            Item {
                id: band

                required property string modelData
                readonly property bool vertical: modelData === "left" || modelData === "right"
                readonly property bool selected: root.selectedEdge === modelData

                x: modelData === "right" ? mini.width - mini.band : vertical ? 0 : mini.cornerSize
                y: modelData === "bottom" ? mini.height - mini.band : vertical ? mini.cornerSize : 0
                width: vertical ? mini.band : mini.width - mini.cornerSize * 2
                height: vertical ? mini.height - mini.cornerSize * 2 : mini.band

                StyledRect {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: Tokens.rounding.small
                    color: band.selected ? Colours.palette.m3secondaryContainer : Colours.palette.m3surfaceContainer
                    border.width: band.selected ? 1 : 0
                    border.color: Colours.palette.m3secondary
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.selectedEdge = band.modelData
                }

                Grid {
                    anchors.fill: parent
                    anchors.margins: 3
                    columns: band.vertical ? 1 : 3
                    spacing: 3

                    Repeater {
                        model: BarLayout.regionNames

                        Zone {
                            required property string modelData

                            width: band.vertical ? parent.width : (parent.width - 6) / 3
                            height: band.vertical ? (parent.height - 6) / 3 : parent.height
                            place: ({
                                    edge: band.modelData,
                                    region: modelData
                                })
                            chips: root.chipsAt(band.modelData, modelData)
                            hint: `${root.edgeLabels[band.modelData]} · ${modelData}`
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

                x: modelData.endsWith("Right") ? mini.width - mini.cornerSize : 0
                y: modelData.startsWith("bottom") ? mini.height - mini.cornerSize : 0
                width: mini.cornerSize
                height: mini.cornerSize
                place: ({
                        corner: modelData
                    })
                corner: true
                chips: root.panelsAt(p => p.corner === modelData)
                hint: "Corner · panels only"
            }
        }
    }

    // ── Hidden icons (drop an icon here to hide it, a panel to put it back
    // where it opens by default) ──
    Surface {
        id: hiddenTray

        width: parent.width
        height: Math.max(56, hiddenFlow.implicitHeight + Tokens.spacing.normal * 2 + 18)
        level: 2
        shape: "small"
        outlined: hiddenDrop.containsDrag

        MicroLabel {
            x: Tokens.spacing.normal
            y: Tokens.spacing.small
            text: "Hidden icons · drop here to hide"
        }

        Flow {
            id: hiddenFlow

            x: Tokens.spacing.normal
            y: Tokens.spacing.small + 18
            width: parent.width - Tokens.spacing.normal * 2
            spacing: 4

            Repeater {
                model: (BarLayout.layout.hidden ?? []).filter(id => BarLayout.catalogue[id]).map(id => ({
                            kind: "widget",
                            id: id,
                            icon: BarLayout.catalogue[id].icon,
                            label: BarLayout.catalogue[id].name
                        }))

                StudioChip {
                    required property var modelData

                    info: modelData
                }
            }
        }

        DropArea {
            id: hiddenDrop

            anchors.fill: parent
            onDropped: drop => {
                const d = drop.source?.info;
                if (!d)
                    return;
                if (d.kind === "widget")
                    BarLayout.hideWidget(d.id);
                else
                    BarLayout.placePanel(d.id, null);
            }
        }
    }

    // ── The selected edge ──
    Sheet {
        width: parent.width
        title: `${root.edgeLabels[root.selectedEdge]} edge`

        Column {
            width: parent.width
            spacing: Tokens.spacing.normal

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
                text: BarLayout.mode(root.selectedEdge) === "regions" ? "Shows (each region)" : "Shows"
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
                        width: 56
                        anchors.verticalCenter: parent.verticalCenter
                        text: visRow.modelData
                    }

                    ButtonGroup {
                        width: parent.width - (visRow.modelData !== "" ? 56 + Tokens.spacing.normal : 0)
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
    }

    // ── Corners: who gets one when both bars have something at that end ──
    Sheet {
        width: parent.width
        title: "Corners"

        Column {
            width: parent.width
            spacing: Tokens.spacing.small

            StyledText {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "A corner goes to the bar with something at that end. When both have, it goes to:"
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
                        width: 90
                        anchors.verticalCenter: parent.verticalCenter
                        text: cornerRow.modelData.label
                    }

                    ButtonGroup {
                        width: parent.width - 90 - Tokens.spacing.normal
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

    // A drop zone: an edge's region or a corner, holding its chips.
    component Zone: Item {
        id: zone

        required property var place
        property var chips: []
        property bool corner: false
        property string hint: ""

        StyledRect {
            anchors.fill: parent
            radius: Tokens.rounding.small
            color: drop.containsDrag ? Colours.palette.m3primaryContainer : zone.corner ? Colours.palette.m3surfaceContainerHigh : "transparent"
            border.width: 1
            border.color: drop.containsDrag ? Colours.palette.m3primary : Colours.palette.m3outlineVariant
        }

        DropArea {
            id: drop

            anchors.fill: parent
            onDropped: d => root.dropAt(d.source?.info, zone.place, "")
        }

        Flow {
            anchors.fill: parent
            anchors.margins: 3
            spacing: 2

            Repeater {
                model: zone.chips

                StudioChip {
                    required property var modelData

                    info: modelData
                    // Dropped on a chip: goes before it.
                    onDroppedOn: d => root.dropAt(d, zone.place, modelData.kind === "widget" ? modelData.id : "")
                }
            }
        }
    }

    // An icon (filled) or panel (outlined) to drag. While dragged, its face
    // floats above everything (reparented to the studio) and follows the
    // pointer; let go, it drops on whatever is under it.
    component StudioChip: Item {
        id: chip

        required property var info
        signal droppedOn(var info)

        width: 21
        height: 21

        DropArea {
            anchors.fill: parent
            onDropped: d => {
                if (d.source?.info && d.source.info !== chip.info)
                    chip.droppedOn(d.source.info);
            }
        }

        Rectangle {
            id: face

            // What a drop target reads.
            readonly property var info: chip.info

            width: chip.width
            height: chip.height
            radius: 5
            color: chip.info.kind === "panel" ? "transparent" : Colours.palette.m3secondaryContainer
            border.width: chip.info.kind === "panel" ? 1 : 0
            border.color: Colours.palette.m3tertiary
            scale: dragArea.drag.active ? 1.25 : dragArea.containsMouse ? 1.1 : 1

            Drag.active: dragArea.drag.active
            Drag.source: face
            Drag.hotSpot.x: width / 2
            Drag.hotSpot.y: height / 2

            MaterialIcon {
                anchors.centerIn: parent
                text: chip.info.icon
                size: 15
                fill: chip.info.kind === "panel" ? 0 : 1
                color: chip.info.kind === "panel" ? Colours.palette.m3tertiary : Colours.palette.m3onSecondaryContainer
            }
        }

        MouseArea {
            id: dragArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            drag.target: face
            onContainsMouseChanged: root.hoverText = containsMouse ? `${chip.info.label} · ${chip.info.kind === "panel" ? "panel" : "icon"}` : ""
            onPressed: {
                const p = face.mapToItem(root, 0, 0);
                face.parent = root;
                face.x = p.x;
                face.y = p.y;
                face.z = 100;
            }
            onReleased: {
                face.Drag.drop();
                face.parent = chip;
                face.x = 0;
                face.y = 0;
            }
        }
    }

    // A labelled action button (Save, Revert).
    component ActionButton: Surface {
        id: button

        property string text
        property string icon
        property bool primary: false

        interactive: enabled
        role: primary ? "primary" : "paper"
        emphasis: primary ? "strong" : "soft"
        shape: "full"
        opacity: enabled ? 1 : 0.4
        implicitWidth: label.implicitWidth + 44
        implicitHeight: 36

        Row {
            id: label

            anchors.centerIn: parent
            spacing: 6

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: button.icon
                size: 18
                color: button.ink
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: button.text
                color: button.ink
                font.weight: Font.DemiBold
            }
        }
    }
}
