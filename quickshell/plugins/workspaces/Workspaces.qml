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

    width: parent?.width ?? 28
    implicitWidth: 28
    implicitHeight: spaces.length * cell + Math.max(0, spaces.length - 1) * gap

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
    readonly property real plateY: Math.max(0, activeIndex) * (cell + gap)

    onPlateYChanged: {
        if (plate.placed && Tokens.goo.enabled && Math.abs(plateY - plate.y) > 1)
            tail.leave(plate.y);
        plate.placed = activeIndex >= 0;
        plate.y = plateY;
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
            group: width > 1 && height > 1 ? plateInk : null
            x: (root.width - width) / 2
            width: 0
            height: 0
            radius: Math.min(width / 2, Tokens.rounding.small)
            deformScale: 0

            function leave(fromY: real): void {
                shrink.stop();
                y = fromY;
                height = root.cell;
                width = root.width;
                shrink.start();
            }

            ParallelAnimation {
                id: shrink

                NumberAnimation {
                    target: tail
                    property: "width"
                    to: 0
                    duration: Tokens.anim.slow
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.anim.emphasizedAccel
                }
                NumberAnimation {
                    target: tail
                    property: "height"
                    to: 0
                    duration: Tokens.anim.slow
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.anim.emphasizedAccel
                }
                NumberAnimation {
                    target: tail
                    property: "y"
                    to: tail.y + root.cell / 2
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

            group: plateInk
            width: root.width
            height: root.cell
            radius: Tokens.rounding.small
            stiffness: Tokens.goo.stiffness
            damping: Tokens.goo.damping
            deformScale: Tokens.goo.enabled ? Tokens.goo.scale * 3.5 : 0
            maxStretch: 0.3

            Behavior on y {
                enabled: plate.placed
                SpringAnimation {
                    spring: Tokens.spring.bouncy.spring
                    damping: Tokens.spring.spatial.damping
                    epsilon: 0.25
                }
            }

            Component.onCompleted: {
                y = root.plateY;
                placed = root.activeIndex >= 0;
            }
        }
    }

    Column {
        width: root.width
        spacing: root.gap

        Repeater {
            model: root.spaces

            Item {
                id: ws

                required property var modelData

                width: root.width
                height: root.cell

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
                            spring: Tokens.spring.bouncy.spring
                            damping: Tokens.spring.bouncy.damping
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
