pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// One edge of the frame as a bar: its three regions from BarLayout (start
// at the top of a vertical edge or the left of a horizontal one, the centre
// in the middle, the end at the far side), down or across. Neighbouring
// widgets of one family share a capsule in that family's colours:
//   workspaces (and any plugin's own)  surface container
//   actions (notifications · clipboard · capture)  secondary container
//   tray                                surface container
//   status (sound · connections · battery)  primary (each opens its corner:
//       sound has brightness and now playing, connections Wi-Fi and Bluetooth)
//   power                               error container
//   clock                               no capsule
// Every control previews its popout on hover; see BarControl.
Item {
    id: root

    property ShellScreen shellScreen
    property string edge: "left"
    readonly property bool horizontal: edge === "top" || edge === "bottom"
    // The same inset as the sides, so the bar's ends match its edges.
    readonly property real endInset: Tokens.spacing.large / 2
    // "full" or "regions" (BarLayout.mode), the bar's thickness across (a
    // full bar's where it has icon widgets) and the thin strip's.
    readonly property string mode: BarLayout.mode(edge)
    readonly property real thick: BarLayout.barThickness(edge)
    readonly property real strip: Tokens.border
    // Where an icon-less widget's middle sits across the bar: in the middle
    // of a full bar, on the strip in regions mode.
    readonly property real stripMiddle: {
        if (mode === "full")
            return thick / 2;
        return edge === "right" || edge === "bottom" ? thick - strip / 2 : strip / 2;
    }

    // In regions mode, the bulges: one per region with icon widgets, as long
    // as they are (and the inset at the bar's ends), the bar's thickness
    // out from the screen edge. In this item's coordinates.
    readonly property var bulges: {
        if (mode !== "regions")
            return [];
        const out = [];
        for (const r of regionItems) {
            const s = r.iconSpan;
            if (!s)
                continue;
            const len = horizontal ? width : height;
            const a = Math.max(0, s[0] - endInset);
            const b = Math.min(len, s[1] + endInset);
            // Autohidden, it sinks back into the strip.
            const t = strip + (thick - strip) * r.reveal;
            out.push(horizontal ? Qt.rect(a, edge === "bottom" ? height - t : 0, b - a, t) : Qt.rect(edge === "right" ? width - t : 0, a, t, b - a));
        }
        return out;
    }
    property var regionItems: []

    // ── Showing and hiding (BarLayout.visibility) ──
    // A full bar shows or hides as one (`reveal`, 0..1, which the frame's
    // thickness follows); in regions mode each region does on its own.
    readonly property string screenName: shellScreen?.name ?? ""
    readonly property bool emptyDesk: {
        const ws = Umbriel.activeWorkspace(screenName);
        return !ws || Umbriel.windowsOn(ws.id).length === 0;
    }
    // Whether a popout from a widget here (in `region`, or anywhere on the
    // edge) is open.
    function popoutOpen(region: string): bool {
        const c = ShellState.current(screenName);
        if (!c.startsWith("bar:"))
            return false;
        const at = BarLayout.popoutPlace(c.slice(4));
        return !!at && at.edge === edge && (!region || at.region === region);
    }
    function wants(vis: string, held: bool, region: string): bool {
        return vis !== "autohide" || held || emptyDesk || popoutOpen(region);
    }

    property bool held: false
    readonly property bool shown: mode !== "full" || wants(BarLayout.visibility(edge, ""), held, "")
    property real reveal: shown ? 1 : 0

    Behavior on reveal {
        Anim {
            duration: Tokens.anim.normal
        }
    }

    // Hovering the bar (its strip, while hidden) shows it; leaving lets it
    // go after the panels' close delay. In regions mode only the region
    // under the pointer (`hoverAlong`, where along the bar it was).
    property real hoverAlong: -1

    HoverHandler {
        onPointChanged: {
            if (hovered)
                root.hoverAlong = root.horizontal ? point.position.x : point.position.y;
        }
        onHoveredChanged: {
            if (hovered) {
                unhold.stop();
                root.held = true;
            } else {
                unhold.restart();
            }
        }
    }

    Timer {
        id: unhold

        interval: ShellState.closeDelay
        onTriggered: root.held = false
    }

    // Where the content slides to while hidden: out past the screen's edge.
    function hideOffset(reveal: real): point {
        const d = (1 - reveal) * thick;
        return edge === "left" ? Qt.point(-d, 0) : edge === "right" ? Qt.point(d, 0) : edge === "top" ? Qt.point(0, -d) : Qt.point(0, d);
    }

    // A family's capsule.
    function style(family: string): var {
        const p = Colours.palette;
        switch (family) {
        case "clock":
            return null;
        case "actions":
            // The pill in the group's inverse (as the status group's), so it
            // stands out on the capsule.
            return {
                fill: p.m3secondaryContainer,
                ink: p.m3onSecondaryContainer,
                pillFill: p.m3onSecondaryContainer,
                pillInk: p.m3secondaryContainer,
                padding: 4,
                radius: Tokens.rounding.normal
            };
        case "status":
            return {
                fill: p.m3primary,
                ink: p.m3onPrimary,
                pillFill: p.m3onPrimary,
                pillInk: p.m3primary,
                padding: 4,
                radius: Tokens.rounding.normal
            };
        case "power":
            return {
                fill: p.m3errorContainer,
                ink: p.m3onErrorContainer,
                pillFill: p.m3error,
                pillInk: p.m3onError,
                padding: 3,
                radius: Tokens.rounding.small
            };
        case "tray":
            return {
                fill: p.m3surfaceContainerHigh,
                ink: p.m3onSurface,
                pillFill: p.m3onSurface,
                pillInk: p.m3surfaceContainerHigh,
                padding: 6,
                radius: Tokens.rounding.normal
            };
        default:
            return {
                fill: p.m3surfaceContainerHigh,
                ink: p.m3onSurface,
                pillFill: p.m3onSurface,
                pillInk: p.m3surfaceContainerHigh,
                padding: 4,
                radius: Tokens.rounding.normal
            };
        }
    }

    // A region's widgets in runs of one family: [{ family, ids }].
    function runs(ids: var): var {
        const out = [];
        for (const id of ids) {
            const family = BarLayout.catalogue[id]?.family ?? id;
            const last = out[out.length - 1];
            if (last && last.family === family && family !== "clock")
                last.ids.push(id);
            else
                out.push({
                    family: family,
                    ids: [id]
                });
        }
        return out;
    }

    // A widget's loader: the kernel's own component, or a plugin's file.
    function load(loader: Loader, id: string): void {
        const k = kernel[id];
        if (k)
            loader.sourceComponent = k;
        else if (BarLayout.catalogue[id]?.url)
            loader.setSource(BarLayout.catalogue[id].url, {
                shellScreen: root.shellScreen
            });
    }

    // What a loaded widget gets: the screen, the bar's direction and edge,
    // and its capsule's inks.
    function wire(item: Item, capsule: Item): void {
        if ("horizontal" in item)
            item.horizontal = Qt.binding(() => root.horizontal);
        if ("edge" in item)
            item.edge = Qt.binding(() => root.edge);
        if ("shellScreen" in item)
            item.shellScreen = Qt.binding(() => root.shellScreen);
        if (capsule && "groupInk" in item) {
            item.groupInk = Qt.binding(() => capsule.ink);
            item.groupActiveInk = Qt.binding(() => capsule.pillInk);
        }
    }

    // The three regions: start and end held to their ends of the bar, the
    // centre in the middle.
    Repeater {
        model: BarLayout.regionNames
        onItemAdded: (i, item) => root.regionItems = root.regionItems.concat([item])
        onItemRemoved: (i, item) => root.regionItems = root.regionItems.filter(r => r !== item)

        Grid {
            id: region

            required property string modelData
            // In regions mode, shown and hidden on its own (hovered: the
            // pointer on the bar along its span); in full mode, with the bar.
            readonly property bool held: {
                const a = root.horizontal ? x : y;
                const len = root.horizontal ? width : height;
                return root.held && root.hoverAlong >= a - root.endInset * 2 && root.hoverAlong <= a + len + root.endInset * 2;
            }
            readonly property bool shown: root.mode === "full" || root.wants(BarLayout.visibility(root.edge, modelData), held, modelData)
            property real reveal: shown ? 1 : 0
            readonly property point slide: root.hideOffset(root.mode === "full" ? root.reveal : reveal)

            Behavior on reveal {
                Anim {
                    duration: Tokens.anim.normal
                }
            }

            opacity: Math.min(1, (root.mode === "full" ? root.reveal : reveal) * 1.5)
            transform: Translate {
                x: region.slide.x
                y: region.slide.y
            }


            // Where its icon widgets run along the bar ([from, to] in the
            // bar's coordinates), or null.
            readonly property var iconSpan: {
                let a = Infinity, b = -Infinity;
                for (const c of children) {
                    if (!c.iconic || !c.visible)
                        continue;
                    const p = root.horizontal ? x + c.x : y + c.y;
                    a = Math.min(a, p);
                    b = Math.max(b, p + (root.horizontal ? c.width : c.height));
                }
                return a < b ? [a, b] : null;
            }

            anchors.top: !root.horizontal && modelData === "start" ? parent.top : undefined
            anchors.bottom: !root.horizontal && modelData === "end" ? parent.bottom : undefined
            anchors.left: root.horizontal && modelData === "start" ? parent.left : undefined
            anchors.right: root.horizontal && modelData === "end" ? parent.right : undefined
            anchors.topMargin: root.endInset
            anchors.bottomMargin: root.endInset
            anchors.leftMargin: root.endInset
            anchors.rightMargin: root.endInset
            anchors.horizontalCenter: !root.horizontal || modelData === "center" ? parent.horizontalCenter : undefined
            anchors.verticalCenter: root.horizontal || modelData === "center" ? parent.verticalCenter : undefined
            columns: root.horizontal ? 64 : 1
            spacing: Tokens.spacing.normal
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter

            Repeater {
                model: root.runs(BarLayout.widgets(root.edge, region.modelData))

                Loader {
                    id: run

                    required property var modelData
                    readonly property var look: root.style(modelData.family)
                    readonly property bool iconic: modelData.ids.some(id => BarLayout.iconic(id))

                    sourceComponent: look ? capsule : bare

                    // An icon-less widget, centred across the bar on its
                    // middle (root.stripMiddle).
                    Component {
                        id: bare

                        Item {
                            implicitWidth: root.horizontal ? single.implicitWidth : root.width
                            implicitHeight: root.horizontal ? root.height : single.implicitHeight

                            Loader {
                                id: single

                                x: root.horizontal ? 0 : root.stripMiddle - width / 2
                                y: root.horizontal ? root.stripMiddle - height / 2 : 0
                                width: root.horizontal ? implicitWidth : root.width
                                height: root.horizontal ? implicitHeight : implicitHeight
                                Component.onCompleted: root.load(single, run.modelData.ids[0])
                                onLoaded: root.wire(item, null)
                            }
                        }
                    }

                    Component {
                        id: capsule

                        BarGroup {
                            id: group

                            horizontal: root.horizontal
                            fill: run.look.fill
                            ink: run.look.ink
                            pillFill: run.look.pillFill
                            pillInk: run.look.pillInk
                            padding: run.look.padding
                            radius: run.look.radius

                            Repeater {
                                model: run.modelData.ids

                                Loader {
                                    id: w

                                    required property string modelData

                                    width: root.horizontal ? implicitWidth : group.width - group.padding * 2
                                    height: root.horizontal ? group.height - group.padding * 2 : implicitHeight
                                    Component.onCompleted: root.load(w, modelData)
                                    onLoaded: root.wire(item, group)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    readonly property var kernel: ({
            clock: clockWidget,
            tray: trayWidget,
            sound: soundWidget,
            connect: connectWidget,
            battery: batteryWidget,
            power: powerWidget
        })

    Component {
        id: clockWidget

        Clock {}
    }

    Component {
        id: trayWidget

        Tray {}
    }

    // The album art while something plays, else the speaker.
    Component {
        id: soundWidget

        BarControl {
            popout: "sound"
            icon: Media.playing && Media.art ? "" : Audio.muted ? "volume_off" : Audio.volume === 0 ? "volume_mute" : Audio.volume < 0.5 ? "volume_down" : "volume_up"
            alert: Audio.muted ? Colours.palette.m3error : "transparent"
            onRightClicked: Audio.toggleMute()
            onMiddleClicked: Media.togglePlaying()
            onScrolled: up => Audio.setVolume(Audio.volume + (up ? 0.05 : -0.05))

            ClippingRectangle {
                visible: Media.playing && Media.art !== ""
                width: 24
                height: 24
                radius: Tokens.rounding.small
                color: "transparent"

                Image {
                    anchors.fill: parent
                    source: Media.art
                    sourceSize: Qt.size(48, 48)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
        }
    }

    // A dot while a Bluetooth device is connected.
    Component {
        id: connectWidget

        BarControl {
            popout: "connect"
            icon: Network.icon
            dot: BluetoothState.connected.length > 0
            onRightClicked: Network.toggleWifi()
        }
    }

    Component {
        id: batteryWidget

        BarControl {
            id: battery

            popout: "battery"
            alert: Power.low ? Colours.palette.m3error : "transparent"

            BatteryIcon {
                ink: battery.ink
                hole: battery.active ? battery.groupInk : battery.groupActiveInk
            }
        }
    }

    Component {
        id: powerWidget

        BarControl {
            popout: "session"
            icon: "power_settings_new"
        }
    }
}
