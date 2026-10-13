pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.components

// The edit mode on the bar (ROADMAP B7; Mod+B, or ✎ in Settings → Bar):
// beside every edge, just inside the frame, a drop zone for each of its
// regions, and one in each corner, holding the chips placed there; the real
// bars and panels re-lay themselves out as chips move (a BarLayout draft).
// Drag a chip, or click it and then where it goes. The toolbar in the middle
// has the presets, Hidden, Revert, Save and Done; Esc is Done. Leaving
// unsaved walks back.
Item {
    id: root

    // The frame's thickness on each edge (the zones sit just inside it).
    required property real tLeft
    required property real tTop
    required property real tRight
    required property real tBottom

    property var picked: null
    readonly property real band: 52
    readonly property real gap: Tokens.spacing.normal

    function isPicked(c: var): bool {
        return picked !== null && picked.kind === c.kind && picked.id === c.id;
    }

    function put(c: var, at: var, before: string): void {
        BarLayout.put(c, at, before);
        picked = null;
    }

    function unplace(c: var): void {
        BarLayout.unplace(c);
        picked = null;
    }

    // Where a zone goes: [x, y, w, h].
    function zoneRect(edge: string, region: string): var {
        const l = tLeft + gap, t = tTop + gap, r = width - tRight - gap, b = height - tBottom - gap;
        const vertical = edge === "left" || edge === "right";
        const from = vertical ? t + band + gap : l + band + gap;
        const to = vertical ? b - band - gap : r - band - gap;
        const len = (to - from - gap * 2) / 3;
        const at = from + BarLayout.regionNames.indexOf(region) * (len + gap);
        switch (edge) {
        case "left":
            return [l, at, band, len];
        case "right":
            return [r - band, at, band, len];
        case "top":
            return [at, t, len, band];
        default:
            return [at, b - band, len, band];
        }
    }

    function cornerRect(corner: string): var {
        const l = tLeft + gap, t = tTop + gap, r = width - tRight - gap, b = height - tBottom - gap;
        return [corner.endsWith("Right") ? r - band : l, corner.startsWith("bottom") ? b - band : t, band, band];
    }

    focus: true
    Keys.onEscapePressed: BarLayout.finishEditing()
    Component.onCompleted: forceActiveFocus()

    // The desktop veiled, so the zones and the bars stand out. A click on
    // it puts down what's picked.
    StyledRect {
        anchors.fill: parent
        color: Qt.alpha(Colours.palette.m3scrim, 0.35)

        MouseArea {
            anchors.fill: parent
            onClicked: root.picked = null
        }
    }

    // The regions' zones.
    Repeater {
        model: BarLayout.edgeNames.reduce((out, e) => out.concat(BarLayout.regionNames.map(r => ({
                        edge: e,
                        region: r
                    }))), [])

        Zone {
            required property var modelData
            readonly property var r: root.zoneRect(modelData.edge, modelData.region)

            x: r[0]
            y: r[1]
            width: r[2]
            height: r[3]
            place: modelData
            chips: BarLayout.chipsAt(modelData.edge, modelData.region)
        }
    }

    // The corners' zones: panels only.
    Repeater {
        model: ["topLeft", "topRight", "bottomLeft", "bottomRight"]

        Zone {
            required property string modelData
            readonly property var r: root.cornerRect(modelData)

            x: r[0]
            y: r[1]
            width: r[2]
            height: r[3]
            place: ({
                    corner: modelData
                })
            chips: BarLayout.panelChips(at => at.corner === modelData)
        }
    }

    // The toolbar.
    Surface {
        id: toolbar

        anchors.centerIn: parent
        width: 520
        height: tools.implicitHeight + Tokens.spacing.large * 2
        level: 2
        shape: "large"

        Column {
            id: tools

            x: Tokens.spacing.large
            y: Tokens.spacing.large
            width: parent.width - Tokens.spacing.large * 2
            spacing: Tokens.spacing.normal

            Sheet {
                width: parent.width
                title: "Edit the bar"
                gloss: "编辑"

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
                    },
                    IconButton {
                        icon: "close"
                        onClicked: BarLayout.finishEditing()
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
                            onClicked: BarLayout.usePreset(modelData.value)
                        }
                    }
                }

                StyledText {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: root.picked ? `${root.picked.label}: click where it goes${root.picked.kind === "icon" ? ", or Hidden" : ""}.` : BarLayout.dirty ? "Unsaved. Save keeps it; Revert or Done (Esc) walks back." : "Drag an icon or a panel to a zone, or click it and then the zone."
                    color: root.picked || BarLayout.dirty ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                    font.pixelSize: Tokens.font.small
                }
            }

            // Hidden: drop or click an icon here to hide it, a panel to put
            // it back where it opens by default.
            Surface {
                id: hidden

                readonly property var chips: BarLayout.hiddenChips()

                width: parent.width
                height: Math.max(52, hiddenFlow.implicitHeight + Tokens.spacing.normal * 2)
                role: hiddenDrop.containsDrag || root.picked !== null ? "primary" : "paper"
                emphasis: "ghost"
                level: 1
                outlined: true
                interactive: root.picked !== null
                onClicked: root.unplace(root.picked)

                StyledText {
                    anchors.centerIn: parent
                    visible: hidden.chips.length === 0
                    text: "Hidden: drop an icon here"
                    color: hidden.subInk
                    font.pixelSize: Tokens.font.small
                }

                Flow {
                    id: hiddenFlow

                    anchors.fill: parent
                    anchors.margins: Tokens.spacing.normal
                    spacing: 4

                    Repeater {
                        model: hidden.chips

                        LayoutChip {
                            required property var modelData

                            info: modelData
                            overlay: dragLayer
                            size: 32
                            isPicked: root.isPicked(modelData)
                            onPick: root.picked = isPicked ? null : modelData
                        }
                    }
                }

                DropArea {
                    id: hiddenDrop

                    function accept(c: var): void {
                        root.unplace(c);
                    }

                    anchors.fill: parent
                }
            }
        }
    }

    Item {
        id: dragLayer

        anchors.fill: parent
        z: 10
    }

    // A drop zone: an edge's region or a corner, with its chips.
    component Zone: Surface {
        id: zone

        required property var place
        property var chips: []
        readonly property bool fitsPicked: BarLayout.fits(root.picked, place)
        readonly property bool target: (drop.containsDrag && BarLayout.fits(drop.drag.source?.info ?? null, place)) || (fitsPicked && hovered)

        role: target ? "primary" : "paper"
        emphasis: target ? "soft" : "soft"
        level: 2
        shape: "normal"
        outlined: true
        interactive: fitsPicked
        opacity: root.picked !== null && !fitsPicked ? 0.45 : 1
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
            anchors.margins: 6
            spacing: 4

            Repeater {
                model: zone.chips

                LayoutChip {
                    required property var modelData

                    info: modelData
                    overlay: dragLayer
                    size: 32
                    isPicked: root.isPicked(modelData)
                    onPick: root.picked = isPicked ? null : modelData
                    // Dropped on an icon: goes before it.
                    onDroppedOn: c => root.put(c, zone.place, modelData.kind === "icon" ? modelData.id : "")
                }
            }
        }
    }
}
