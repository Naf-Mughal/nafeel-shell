pragma ComponentBehavior: Bound

import QtQuick
import Nafeel
import Quickshell
import qs.config
import qs.services
import qs.components
import qs.modules.bar.popouts
import "tabs"

// The dock and, grown up out of it, the command center: the search on top,
// the tabs down the side, the current tab beside them (fixed size; switching
// tabs cross-fades the content), and the dock as the base.
Item {
    id: root

    required property bool expanded
    property ShellScreen shellScreen

    readonly property int dockHeight: 72
    readonly property real dockWidth: dock.implicitWidth
    // The app whose windows preview above the dock (not while expanded).
    readonly property var previewItem: !expanded && ShellState.dockPreview !== "" && ShellState.dockPreviewScreen === (shellScreen?.name ?? "") ? (Dock.items.find(i => i.appId === ShellState.dockPreview && i.windows.length > 0) ?? null) : null
    // What the previews add to the panel (the drawer grows by it).
    readonly property real previewHeight: previewItem ? preview.implicitHeight + pad * 2 : 0
    readonly property real previewWidth: previewItem ? preview.implicitWidth : 0
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
    }

    // The command center, above the dock.
    Item {
        id: cc

        x: root.pad
        y: root.pad
        width: parent.width - root.pad * 2
        height: parent.height - root.dockHeight - root.pad
        opacity: root.expanded ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            Anim {
                duration: Tokens.anim.fast
            }
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
                    target: loader
                    property: "opacity"
                    to: 0
                    duration: Tokens.dur(80)
                }
                ScriptAction {
                    script: page.shown = ShellState.ccTab
                }
                NumberAnimation {
                    target: loader
                    property: "opacity"
                    to: 1
                    duration: Tokens.dur(160)
                }
            }

            Loader {
                id: loader

                readonly property var pluginTab: Plugins.tabs.find(t => t.id === page.shown) ?? null

                anchors.fill: parent
                onLoaded: Choreo.cascade(item?.contentItem ?? item, 40)
                active: root.expanded
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
                    })[page.shown] ?? (pluginTab ? (pluginTab.popout ? pluginPopoutTab : Qt.createComponent(pluginTab.url)) : home)
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
            // A plugin's popout-sized panel, centred as the bar popouts are.
            Component {
                id: pluginPopoutTab

                PopoutTab {
                    contentUrl: loader.pluginTab?.url ?? ""
                }
            }
        }
    }

    // The previews, part of the panel: above the dock while one is shown.
    DockPreview {
        id: preview

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: dock.top
        anchors.bottomMargin: root.pad
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

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        expanded: root.expanded
        screenName: root.shellScreen?.name ?? ""
    }
}
