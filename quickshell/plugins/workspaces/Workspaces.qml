pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Nafeel
import qs.config
import qs.services
import qs.components

// This screen's umbriel workspaces as Chinese numerals (一 二 三 …): the
// active one on a gold plate that springs between them, occupied ones in full
// ink, empty ones faint. Click to switch, scroll to step through them, and
// rest on it (or click empty space) for the workspace previews in the
// top-left corner.
Item {
    id: root

    property ShellScreen shellScreen
    readonly property string output: shellScreen?.name ?? ""
    readonly property var spaces: Umbriel.workspacesOn(output)
    readonly property int activeIndex: spaces.findIndex(w => w.active)
    readonly property int cell: 30
    readonly property string key: "bar:workspaces"

    readonly property int gap: 2
    // Across a horizontal bar instead of down.
    property bool horizontal: false
    readonly property real span: spaces.length * cell + Math.max(0, spaces.length - 1) * gap

    // So a popout out of an edge can grow from it (ShellState.anchorTo).
    Component.onCompleted: ShellState.barControls[key] = root
    Component.onDestruction: {
        if (ShellState.barControls[key] === root)
            delete ShellState.barControls[key];
    }

    width: parent?.width ?? 28
    implicitWidth: horizontal ? span : 28
    implicitHeight: horizontal ? 28 : span

    Timer {
        id: hoverDelay

        interval: 260
        onTriggered: ShellState.preview(root.key, root.output)
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered) {
                ShellState.barHover = root.key;
                hoverDelay.restart();
            } else {
                if (ShellState.barHover === root.key)
                    ShellState.barHover = "";
                hoverDelay.stop();
                ShellState.unpreviewLater(root.key);
            }
        }
        onPointChanged: {
            if (hovered)
                ShellState.keep(root.key);
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => Umbriel.dispatch(event.angleDelta.y > 0 ? "workspace-previous" : "workspace-next")
    }

    // The gold plate under the active numeral: a goo blob (the frame's
    // engine, as the bar's pills) that springs to the active workspace,
    // stretching as it goes, and splits off a tail that shrinks away where it
    // was.
    readonly property real plateAt: Math.max(0, activeIndex) * (cell + gap)

    onPlateAtChanged: {
        if (plate.placed && Tokens.goo.enabled && Math.abs(plateAt - plate.along) > 1)
            tail.leave(plate.along);
        plate.placed = activeIndex >= 0;
        plate.along = plateAt;
    }

    Item {
        anchors.fill: parent
        opacity: root.activeIndex >= 0 ? 1 : 0

        BlobGroup {
            id: plateInk

            color: Colours.palette.m3primary
            smoothing: 10
        }

        BlobRect {
            id: tail

            // Only drawn while it has real size: a sliver on its way to
            // nothing would show as a hairline across the bar.
            // Along the bar and across it.
            property real along: 0
            property real length: 0
            property real breadth: 0
            readonly property real crossSize: root.horizontal ? root.height : root.width

            group: length > 1 && breadth > 1 ? plateInk : null
            x: root.horizontal ? along : (crossSize - breadth) / 2
            y: root.horizontal ? (crossSize - breadth) / 2 : along
            width: root.horizontal ? length : breadth
            height: root.horizontal ? breadth : length
            radius: Math.min(breadth / 2, Tokens.rounding.small)
            deformScale: 0

            function leave(from: real): void {
                shrink.stop();
                along = from;
                length = root.cell;
                breadth = crossSize;
                shrink.start();
            }

            ParallelAnimation {
                id: shrink

                NumberAnimation {
                    target: tail
                    property: "breadth"
                    to: 0
                    duration: Tokens.anim.slow
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.anim.emphasizedAccel
                }
                NumberAnimation {
                    target: tail
                    property: "length"
                    to: 0
                    duration: Tokens.anim.slow
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.anim.emphasizedAccel
                }
                NumberAnimation {
                    target: tail
                    property: "along"
                    to: tail.along + root.cell / 2
                    duration: Tokens.anim.slow
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.anim.emphasizedAccel
                }
            }
        }

        BlobRect {
            id: plate

            // Shown at a workspace yet (the first placement is instant).
            property bool placed: false

            property real along: 0

            group: plateInk
            x: root.horizontal ? along : 0
            y: root.horizontal ? 0 : along
            width: root.horizontal ? root.cell : root.width
            height: root.horizontal ? root.height : root.cell
            radius: Tokens.rounding.small
            stiffness: Tokens.goo.stiffness
            damping: Tokens.goo.damping
            deformScale: Tokens.goo.enabled ? Tokens.goo.scale * 3.5 : 0
            maxStretch: 0.3

            Behavior on along {
                enabled: plate.placed
                SpringAnimation {
                    spring: Tokens.spring.control.spring
                    damping: Tokens.spring.control.damping
                    epsilon: 0.25
                }
            }

            Component.onCompleted: {
                along = root.plateAt;
                placed = root.activeIndex >= 0;
            }
        }
    }

    Grid {
        columns: root.horizontal ? 64 : 1
        spacing: root.gap

        Repeater {
            // Diffed by id (ScriptModel): umbriel resends the list at every
            // focus change; a new array rebuilt every pill each time.
            model: ScriptModel {
                values: root.spaces
                objectProp: "id"
            }

            Item {
                id: ws

                required property var modelData

                width: root.horizontal ? root.cell : root.width
                height: root.horizontal ? root.height : root.cell

                StyledText {
                    anchors.centerIn: parent
                    text: Xian.numeral(ws.modelData.index)
                    color: ws.modelData.active ? Colours.palette.m3onPrimary : ws.modelData.occupied ? Colours.palette.m3onSurface : Colours.palette.m3outline
                    opacity: ws.modelData.active || ws.modelData.occupied ? 1 : 0.55
                    font.family: Tokens.font.cjk
                    font.pixelSize: 16
                    font.weight: ws.modelData.active ? Font.Bold : Font.Medium
                    scale: tap.pressed ? 0.85 : hover.hovered && !ws.modelData.active ? 1.15 : 1

                    Behavior on scale {
                        SpringAnimation {
                            spring: Tokens.spring.control.spring
                            damping: Tokens.spring.control.damping
                            epsilon: 0.002
                        }
                    }
                }

                HoverHandler {
                    id: hover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    id: tap

                    onTapped: Umbriel.dispatch(`workspace-switch:${ws.modelData.name}/${root.output}`)
                }
            }
        }
    }
}
