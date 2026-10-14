pragma ComponentBehavior: Bound

import QtQuick
import Nafeel
import Quickshell
import qs.config
import qs.services
import qs.components
import qs.modules.bar.popouts
import "tabs"

// The dock and, grown out of it, the command center: the search on top,
// the tabs down the side, the current tab beside them (fixed size; switching
// tabs cross-fades the content), and the dock as the base, on the edge it's
// on (BarLayout.dockPlace): across the bottom or top, down a side (the
// command center and the previews then beside it).
Item {
    id: root

    required property bool expanded

    property ShellScreen shellScreen
    property string edge: "bottom"
    readonly property bool vertical: edge === "left" || edge === "right"

    // The dock's depth out of its edge, and its length along it.
    readonly property int dockHeight: 72
    readonly property real dockWidth: vertical ? dock.implicitHeight : dock.implicitWidth
    // The app whose windows preview above the dock (not while expanded).
    readonly property var previewItem: !expanded && ShellState.dockPreview !== "" && ShellState.dockPreviewScreen === (shellScreen?.name ?? "") ? (Dock.items.find(i => i.appId === ShellState.dockPreview && i.windows.length > 0) ?? null) : null
    // What the previews add to the panel (the drawer grows by it).
    // (Across a horizontal edge they sit above or below the dock: the height
    // is depth, the width length; down a side, beside it: the other way.)
    readonly property real previewHeight: previewItem ? (vertical ? preview.implicitWidth : preview.implicitHeight) + pad * 2 : 0
    readonly property real previewWidth: previewItem ? (vertical ? preview.implicitHeight : preview.implicitWidth) : 0
    readonly property int pad: Tokens.spacing.large

    // Launcher state, shared with the search bar and the Apps tab.
    readonly property string query: ShellState.ccQuery
    readonly property string mode: query.startsWith(">") ? "command" : query.startsWith("=") ? "calc" : "apps"
    property int selected: 0
    readonly property var results: mode === "apps" ? Apps.search(query) : []

    // The kernel's tabs, then the plugins' (Plugins.tabs).
    readonly property var tabs: [
        { id: "home", icon: "home", label: "Home" },
        { id: "apps", icon: "apps", label: "Apps" },
        { id: "media", icon: "music_note", label: "Media" },
        { id: "audio", icon: "volume_up", label: "Audio" },
        { id: "display", icon: "light_mode", label: "Display" },
        { id: "system", icon: "monitoring", label: "System" },
        { id: "power", icon: "battery_full", label: "Power" },
        { id: "network", icon: "wifi", label: "Network" },
        { id: "bluetooth", icon: "bluetooth", label: "Bluetooth" },
        { id: "weather", icon: "partly_cloudy_day", label: "Weather" },
        { id: "calendar", icon: "calendar_month", label: "Calendar" }
    ].concat(Plugins.tabs)

    function move(by: int): void {
        if (ShellState.ccTab !== "apps")
            ShellState.ccTab = "apps";
        if (results.length > 0)
            selected = (selected + by + results.length) % results.length;
    }

    function cycleTab(by: int): void {
        const i = tabs.findIndex(t => t.id === ShellState.ccTab);
        ShellState.ccTab = tabs[(i + by + tabs.length) % tabs.length].id;
    }

    function activate(): void {
        if (mode === "command") {
            const cmd = query.slice(1).trim();
            if (cmd)
                Quickshell.execDetached(["sh", "-c", cmd]);
        } else if (mode === "calc") {
            if (Calc.result)
                Clipboard.copyText(Calc.result);
        } else {
            const app = results[selected];
            if (!app)
                return;
            Apps.launch(app);
        }
        ShellState.ccQuery = "";
        ShellState.close();
    }

    // (`mode` may not have caught up with `query` yet here.)
    onQueryChanged: {
        if (query.startsWith("="))
            Calc.evaluate(query.slice(1));
    }

    Connections {
        target: ShellState

        function onCcFocusChanged(): void {
            Qt.callLater(() => search.focusInput());
        }

        // Opened (a keybind, the dock, a hover): typing goes to the search
        // and its arrows move through the results at once.
        function onKeyboardGranted(req: var): void {
            if (ShellState.current(ShellState.screen) === "command") {
                search.focusInput();
                req.taken = true;
            }
        }
    }

    // The command center, above the dock.
    Item {
        id: cc

        x: root.edge === "left" ? root.dockHeight : root.pad
        y: root.edge === "top" ? root.dockHeight : root.pad
        width: parent.width - (root.vertical ? root.dockHeight + root.pad : root.pad * 2)
        height: parent.height - (root.vertical ? root.pad * 2 : root.dockHeight + root.pad)
        opacity: 0
        visible: opacity > 0

        // In on the standard curve; out on emphasized accelerate, as the
        // drawers leave (fading out fast-first dropped most of it in the
        // close's first frame).
        Connections {
            target: root

            function onExpandedChanged(): void {
                ccFade.stop();
                ccFade.to = root.expanded ? 1 : 0;
                ccFade.duration = root.expanded ? Tokens.anim.fast : Tokens.dur(240);
                ccFade.easing.bezierCurve = root.expanded ? Tokens.anim.standard : Tokens.anim.exit;
                ccFade.start();
            }
        }
        Component.onCompleted: opacity = root.expanded ? 1 : 0

        NumberAnimation {
            id: ccFade

            target: cc
            property: "opacity"
            easing.type: Easing.BezierSpline
        }

        SearchBar {
            id: search

            width: parent.width
            cc: root
        }

        Sidebar {
            id: sidebar

            anchors.top: search.bottom
            anchors.topMargin: Tokens.spacing.large
            anchors.bottom: parent.bottom
            width: 176
            tabs: root.tabs
        }

        // The current tab, cross-faded on change.
        Item {
            id: page

            property string shown: ShellState.ccTab

            anchors.top: search.bottom
            anchors.topMargin: Tokens.spacing.large
            anchors.left: sidebar.right
            anchors.leftMargin: Tokens.spacing.large
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            Connections {
                target: ShellState

                function onCcTabChanged(): void {
                    swap.restart();
                }
            }

            SequentialAnimation {
                id: swap

                NumberAnimation {
                    target: page
                    property: "opacity"
                    to: 0
                    duration: Tokens.dur(80)
                }
                ScriptAction {
                    script: page.shown = ShellState.ccTab
                }
                NumberAnimation {
                    target: page
                    property: "opacity"
                    to: 1
                    duration: Tokens.dur(160)
                }
            }

            // Each tab its own content, built ahead (Prewarm) and kept, the
            // current one shown: switching never rebuilds a tab (ROADMAP O4).
            Repeater {
                model: root.tabs

                Loader {
                    id: tabLoader

                    required property var modelData
                    readonly property string tabId: modelData.id
                    readonly property var pluginTab: Plugins.tabs.find(t => t.id === tabId) ?? null
                    readonly property bool shown: page.shown === tabId
                    property int turn: -1

                    anchors.fill: parent
                    visible: shown
                    // Its place in the warm-up queue, taken once.
                    Component.onCompleted: turn = Prewarm.enlist(`command center ${tabId}`)
                    active: (shown && root.expanded) || Prewarm.due(turn)
                    asynchronous: !(shown && root.expanded)
                    onShownChanged: {
                        if (shown && item)
                            Choreo.cascade(item.contentItem ?? item, 40);
                    }
                    sourceComponent: ({
                            home: home,
                            apps: apps,
                            media: media,
                            audio: audio,
                            display: display,
                            system: system,
                            power: power,
                            network: network,
                            bluetooth: bluetooth,
                            weather: weather,
                            calendar: calendar
                        })[tabId] ?? (pluginTab ? (pluginTab.popout ? pluginPopoutTab : Qt.createComponent(pluginTab.url)) : null)

                    // A plugin's popout-sized panel, centred as the bar
                    // popouts are.
                    Component {
                        id: pluginPopoutTab

                        PopoutTab {
                            contentUrl: tabLoader.pluginTab?.url ?? ""
                        }
                    }
                }
            }

            Component {
                id: home

                HomeTab {}
            }
            Component {
                id: apps

                AppsTab {
                    cc: root
                }
            }
            Component {
                id: system

                SystemTab {}
            }
            Component {
                id: weather

                WeatherTab {}
            }
            Component {
                id: calendar

                CalendarTab {}
            }
            Component {
                id: media

                PopoutTab {
                    content: MediaPopout {}
                }
            }
            Component {
                id: audio

                PopoutTab {
                    content: AudioPopout {}
                }
            }
            Component {
                id: display

                PopoutTab {
                    content: BrightnessPopout {}
                }
            }
            Component {
                id: power

                PopoutTab {
                    content: BatteryPopout {}
                }
            }
            Component {
                id: network

                PopoutTab {
                    content: NetworkPopout {}
                }
            }
            Component {
                id: bluetooth

                PopoutTab {
                    content: BluetoothPopout {}
                }
            }
        }
    }

    // The previews, part of the panel: above the dock while one is shown.
    DockPreview {
        id: preview

        // Off the dock, on the side away from the edge.
        x: root.vertical ? (root.edge === "left" ? dock.x + dock.width + root.pad : dock.x - width - root.pad) : (parent.width - width) / 2
        y: root.vertical ? (parent.height - height) / 2 : (root.edge === "top" ? dock.y + dock.height + root.pad : dock.y - height - root.pad)
        item: root.previewItem
        opacity: root.previewItem ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            Anim {
                duration: Tokens.anim.fast
            }
        }
    }

    // Leaving the dock (and its previews) puts the previews away.
    HoverHandler {
        id: dockArea
    }

    Timer {
        running: !dockArea.hovered && ShellState.dockPreview !== ""
        interval: ShellState.closeDelay
        onTriggered: ShellState.dockPreview = ""
    }

    DockBar {
        id: dock

        // Against its edge, centred along it.
        x: root.vertical ? (root.edge === "left" ? 4 : parent.width - width - 4) : (parent.width - width) / 2
        y: root.vertical ? (parent.height - height) / 2 : (root.edge === "top" ? 4 : parent.height - height - 4)
        vertical: root.vertical
        expanded: root.expanded
        screenName: root.shellScreen?.name ?? ""
    }
}
