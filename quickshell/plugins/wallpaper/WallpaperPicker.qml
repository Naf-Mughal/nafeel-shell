pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components
import qs.plugins.osd

// The wallpaper picker (Mod+W), after Ryoku's (ryogami wall-ui, MIT) in the
// shell's own hand: views (Ryoku's slice carousel, the strip, a mosaic),
// filters (folder, the wallpaper's colour as the palette reads it, dark or
// light, favourites, a search), sorts (name, colour wheel, recent, most
// used) over the library index (Wallpapers).
//
// The store (Wallhaven, the storefront button) shows in the same views with
// its own filters; choosing a result downloads it into ~/Pictures/Wallpapers/
// wallhaven and chooses it. Scrolling near the end fetches the next page.
//
// Click one to choose it (its palette is made meanwhile); it's set when the
// picker closes, under the shell's ink transition, with the theme. Double
// click or Enter: choose and close. Keys: type to search, arrows move, Esc
// closes, Ctrl+F favourite, Ctrl+1/2/3 the views.
Item {
    id: root

    // The plugin's stores and rotation (its root).
    readonly property var studio: Plugins.instance("wallpaper")
    // The room the drawer has (set by the frame for content-sized drawers):
    // the picker sizes itself to its view, as Ryoku's slice band runs nearly
    // the screen's width.
    property real availableWidth: 1600
    readonly property real screenWidth: availableWidth + 2 * Tokens.barWidth
    implicitWidth: (Wallpapers.view === "slice" ? availableWidth - 120 : Math.min(1280, screenWidth - 260)) - 2 * Tokens.spacing.large
    implicitHeight: (Wallpapers.view === "mosaic" ? 560 : Wallpapers.view === "slice" ? 600 : 330) + (Quickshell.screens.length > 1 ? 36 : 0) - 2 * Tokens.spacing.large

    readonly property bool store: Wallpapers.source === "store"
    // The store's active provider (Wallhaven or motionbgs).
    readonly property var shop: Wallpapers.store
    readonly property bool live: Wallpapers.provider === "motionbgs"
    readonly property var walls: store ? shop.results : Wallpapers.shown
    readonly property Item view: viewLoader.item
    readonly property int index: view?.currentIndex ?? 0

    // Ryoku's twelve hue swatches, in the palette's (Oklab) hues so a swatch
    // finds what the theme would call that colour; then black and white.
    readonly property var swatches: ["#e680a1", "#eb8373", "#df8f48", "#c4a032", "#9ab04b", "#62bb78", "#06bfa8", "#00b9cf", "#4baeed", "#859ff6", "#b191ea", "#d285cb"]

    function move(dx: int, dy: int): void {
        view?.move(dx, dy);
    }

    // Choose the selected one; `close`: and set it now.
    function choose(close: bool): void {
        const w = walls[index];
        if (!w)
            return;
        if (w.remote)
            // Downloaded first; chosen (or set, if the picker has closed) then.
            Wallpapers.fetch(w);
        else
            Wallpapers.choose(w.path);
        if (close)
            ShellState.close();
    }

    function apply(): void {
        choose(true);
    }

    function centreOnCurrent(): void {
        if (store) {
            if (shop.page <= 1)
                view?.centreOn(0);
            return;
        }
        if (Wallpapers.query)
            return;
        const i = walls.findIndex(w => w.path === (Wallpapers.chosen || Wallpapers.wallpaperOf(Wallpapers.target)));
        if (i >= 0)
            view?.centreOn(i);
    }

    Component.onCompleted: Qt.callLater(() => search.focusInput())

    Subscribe {
        topic: "picker.step"
        onReceived: p => root.move(p.n ?? 1, 0)
    }
    onWallsChanged: {
        // The store's next page only adds to the end: stay where you are.
        if (!store || shop.page <= 1)
            Qt.callLater(centreOnCurrent);
    }

    function toggleStore(): void {
        Wallpapers.source = store ? "library" : "store";
        if (Wallpapers.source === "store")
            Wallpapers.useProvider(Wallpapers.provider);
    }

    // Near the end of the store's results: the next page.
    Connections {
        target: root.view
        ignoreUnknownSignals: true

        function onCurrentIndexChanged(): void {
            if (root.store && root.view.currentIndex >= root.walls.length - 6)
                root.shop.more();
        }
        function onAtYEndChanged(): void {
            if (root.store && root.view.atYEnd)
                root.shop.more();
        }
        function onAtXEndChanged(): void {
            if (root.store && root.view.atXEnd)
                root.shop.more();
        }
    }

    // The keyboard goes to the search when the picker is pinned.
    Connections {
        target: ShellState

        function onKeyboardGranted(req: var): void {
            if (ShellState.pinned === "wallpapers") {
                search.focusInput();
                req.taken = true;
            }
        }
    }

    // ── Heading: title, count, search, sort, views, shuffle ──
    Item {
        id: head

        width: parent.width
        height: 40

        GlossTitle {
            id: title

            anchors.verticalCenter: parent.verticalCenter
            text: "Wallpaper"
            gloss: "画卷"
            size: Tokens.font.value
        }

        // The OSD shows here while the picker is open, between the title
        // and the tools.
        Item {
            anchors.left: title.right
            anchors.right: tools.left
            anchors.margins: Tokens.spacing.normal
            height: parent.height

            OsdInline {}
        }

        Row {
            id: tools

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.spacing.small

            MicroLabel {
                anchors.verticalCenter: parent.verticalCenter
                text: root.store ? (root.shop.error ? root.shop.error : root.shop.loading ? "searching…" : root.live ? `${root.walls.length} live` : `${root.walls.length} results · page ${root.studio.wallhaven.page}/${root.studio.wallhaven.lastPage}`) : Wallpapers.indexing ? `indexing ${Math.round(Wallpapers.indexProgress * 100)}%` : `${root.walls.length} / ${Wallpapers.all.length}`
                color: root.store && root.shop.error ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
            }

            TextField {
                id: search

                anchors.verticalCenter: parent.verticalCenter
                width: 240
                implicitHeight: 36
                placeholder: root.store ? (root.live ? "Search live wallpapers" : "Search Wallhaven") : "Search wallpapers"
                text: root.store ? root.shop.query : Wallpapers.query
                onTextChanged: {
                    if (root.store)
                        root.shop.query = text;
                    else
                        Wallpapers.query = text;
                }
                onAccepted: root.apply()
                keyFilter: event => {
                    const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
                    if (event.key === Qt.Key_Left) {
                        root.move(-1, 0);
                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                        root.move(1, 0);
                    } else if (event.key === Qt.Key_Up) {
                        root.move(0, -1);
                    } else if (event.key === Qt.Key_Down) {
                        root.move(0, 1);
                    } else if (event.key === Qt.Key_Home) {
                        root.view?.centreOn(0);
                    } else if (event.key === Qt.Key_End) {
                        root.view?.centreOn(root.walls.length - 1);
                    } else if (ctrl && event.key === Qt.Key_F) {
                        const w = root.walls[root.index];
                        if (w)
                            Wallpapers.toggleFavourite(w.path);
                    } else if (ctrl && event.key >= Qt.Key_1 && event.key <= Qt.Key_3) {
                        Wallpapers.view = ["slice", "strip", "mosaic"][event.key - Qt.Key_1];
                    } else {
                        return;
                    }
                    event.accepted = true;
                }
            }

            // Sort: name, colour wheel, recent, most used (click cycles).
            IconButton {
                visible: !(root.store && root.live)
                readonly property var modes: root.store ? ["toplist", "hot", "date_added", "random", "views", "favorites"] : ["name", "colour", "recent", "used"]
                readonly property var icons: ({
                        name: "sort_by_alpha",
                        colour: "palette",
                        recent: "schedule",
                        used: "trending_up",
                        toplist: "military_tech",
                        hot: "local_fire_department",
                        date_added: "schedule",
                        random: "casino",
                        views: "visibility",
                        favorites: "favorite"
                    })
                readonly property string mode: root.store ? root.studio.wallhaven.sorting : Wallpapers.sortMode

                icon: icons[mode] ?? "sort"
                size: 36
                caption: mode === "date_added" ? "latest" : mode === "toplist" ? "top" : mode
                onClicked: {
                    const next = modes[(modes.indexOf(mode) + 1) % modes.length];
                    if (root.store)
                        root.studio.wallhaven.sorting = next;
                    else
                        Wallpapers.sortMode = next;
                }
            }

            // Rotation: the filter row becomes its settings.
            IconButton {
                icon: "autorenew"
                size: 36
                filled: root.rotating || root.studio.rotation.enabled
                caption: root.studio.rotation.enabled ? root.every(root.studio.rotation.minutes) : ""
                onClicked: root.rotating = !root.rotating
            }

            // The store: your library <-> root.studio.wallhaven.
            IconButton {
                icon: "storefront"
                size: 36
                filled: root.store
                caption: root.store ? "store" : ""
                onClicked: root.toggleStore()
            }

            Repeater {
                model: [["slice", "view_week"], ["strip", "view_carousel"], ["mosaic", "grid_view"]]

                IconButton {
                    required property var modelData

                    icon: modelData[1]
                    size: 36
                    filled: Wallpapers.view === modelData[0]
                    onClicked: Wallpapers.view = modelData[0]
                }
            }

            IconButton {
                visible: !root.store
                icon: "shuffle"
                size: 36
                onClicked: {
                    // A random one of those shown, chosen (and shown) like a click.
                    const others = root.walls.filter(w => w.path !== Wallpapers.current);
                    if (others.length === 0)
                        return;
                    const pick = others[Math.floor(Math.random() * others.length)];
                    root.view?.centreOn(root.walls.indexOf(pick));
                    Wallpapers.choose(pick.path);
                }
            }
        }
    }

    // The rotation's settings showing in place of the filters.
    property bool rotating: false

    function every(m: int): string {
        return m >= 1440 ? `${m / 1440} d` : m >= 60 ? `${m / 60} h` : `${m} min`;
    }

    function cycle(list: var, value: var): var {
        return list[(Math.max(0, list.indexOf(value)) + 1) % list.length];
    }

    readonly property var rotationChips: {
        const folders = Wallpapers.folders;
        const froms = ["all", "favourites", "shown", ...folders.map(f => "folder:" + f)];
        const fromName = f => f === "all" ? "Everything" : f === "favourites" ? "Favourites" : f === "shown" ? "What's shown" : f.slice(7);
        const chips = [
            {
                text: root.studio.rotation.enabled ? "Rotating" : "Off",
                on: root.studio.rotation.enabled,
                act: () => Settings.set("rotation.enabled", !root.studio.rotation.enabled)
            },
            {
                text: "Every " + every(root.studio.rotation.minutes),
                on: true,
                act: () => Settings.set("rotation.minutes", cycle(root.studio.rotation.everyChoices, root.studio.rotation.minutes))
            },
            {
                text: "From " + fromName(root.studio.rotation.from),
                on: true,
                disabled: root.studio.rotation.dayNight,
                act: () => Settings.set("rotation.from", cycle(froms, root.studio.rotation.from))
            },
            {
                text: root.studio.rotation.order === "random" ? "Shuffled" : "In order",
                on: true,
                act: () => Settings.set("rotation.order", root.studio.rotation.order === "random" ? "sequence" : "random")
            },
            {
                text: "Day & night",
                on: root.studio.rotation.dayNight,
                act: () => Settings.set("rotation.dayNight", !root.studio.rotation.dayNight)
            }
        ];
        if (root.studio.rotation.dayNight) {
            chips.push({
                text: "☀ " + (root.studio.rotation.dayFolder || "pick a folder"),
                on: root.studio.rotation.isDay,
                act: () => Settings.set("rotation.dayFolder", cycle(folders, root.studio.rotation.dayFolder))
            }, {
                text: "☾ " + (root.studio.rotation.nightFolder || "pick a folder"),
                on: !root.studio.rotation.isDay,
                act: () => Settings.set("rotation.nightFolder", cycle(folders, root.studio.rotation.nightFolder))
            });
        }
        chips.push({
            text: "Next now",
            on: false,
            act: () => root.studio.rotation.next()
        });
        return chips;
    }

    readonly property var ranges: ["1d", "3d", "1w", "1M", "3M", "6M", "1y"]
    readonly property var ratioCycle: [["landscape", "Landscape"], ["16x9", "16:9"], ["21x9", "21:9"], ["portrait", "Portrait"], ["", "Any ratio"]]
    readonly property var providerChip: ({
            text: root.live ? "▶ Live · motionbgs" : "Wallhaven",
            on: true,
            act: () => Wallpapers.useProvider(root.live ? "wallhaven" : "motionbgs")
        })
    readonly property var storeChips: {
        if (root.live)
            return [providerChip, {
                    text: root.studio.motionbgs.quality === "4k" ? "4K when offered" : "HD (1080p)",
                    on: true,
                    act: () => root.studio.motionbgs.quality = root.studio.motionbgs.quality === "4k" ? "hd" : "4k"
                }];
        const key = Wallpapers.settings.v.wallhavenKey !== "";
        const ri = ratioCycle.findIndex(r => r[0] === root.studio.wallhaven.ratios);
        const chips = [providerChip,
            {
                text: "General",
                on: root.studio.wallhaven.general,
                act: () => root.studio.wallhaven.general = !root.studio.wallhaven.general
            },
            {
                text: "Anime",
                on: root.studio.wallhaven.anime,
                act: () => root.studio.wallhaven.anime = !root.studio.wallhaven.anime
            },
            {
                text: "People",
                on: root.studio.wallhaven.people,
                act: () => root.studio.wallhaven.people = !root.studio.wallhaven.people
            },
            {
                text: "Sketchy",
                on: root.studio.wallhaven.sketchy && key,
                disabled: !key,
                act: () => root.studio.wallhaven.sketchy = !root.studio.wallhaven.sketchy
            },
            {
                text: "NSFW",
                on: root.studio.wallhaven.nsfw && key,
                disabled: !key,
                act: () => root.studio.wallhaven.nsfw = !root.studio.wallhaven.nsfw
            },
            {
                text: ratioCycle[Math.max(0, ri)][1],
                on: root.studio.wallhaven.ratios !== "",
                act: () => root.studio.wallhaven.ratios = ratioCycle[(Math.max(0, ri) + 1) % ratioCycle.length][0]
            },
            {
                text: root.studio.wallhaven.atleast ? `≥ ${root.studio.wallhaven.atleast}` : "Any size",
                on: root.studio.wallhaven.atleast !== "",
                act: () => root.studio.wallhaven.atleast = root.studio.wallhaven.atleast ? "" : (Quickshell.screens.length ? `${Quickshell.screens[0].width}x${Quickshell.screens[0].height}` : "1920x1080")
            }
        ];
        if (root.studio.wallhaven.sorting === "toplist")
            chips.push({
                text: `Top ${root.studio.wallhaven.topRange}`,
                on: true,
                act: () => root.studio.wallhaven.topRange = ranges[(ranges.indexOf(root.studio.wallhaven.topRange) + 1) % ranges.length]
            });
        return chips;
    }

    // ── Which screen (only with more than one): every screen, or one ──
    Row {
        id: screensRow

        anchors.top: head.bottom
        anchors.topMargin: visible ? Tokens.spacing.small : 0
        height: visible ? 30 : 0
        visible: Quickshell.screens.length > 1
        spacing: Tokens.spacing.small

        MicroLabel {
            anchors.verticalCenter: parent.verticalCenter
            text: "for"
        }

        Repeater {
            model: ["", ...Quickshell.screens.map(s => s.name)]

            Chip {
                required property string modelData

                icon: modelData ? (modelData === Wallpapers.mainOutput ? "monitor_heart" : "monitor") : "select_all"
                text: modelData ? modelData + (modelData === Wallpapers.mainOutput ? " · colours" : "") : "Every screen"
                selected: Wallpapers.target === modelData
                onClicked: Wallpapers.target = modelData
            }
        }
    }

    // ── Filters: folders, colour, tone, favourites ──
    Item {
        id: filters

        anchors.top: screensRow.bottom
        anchors.topMargin: Tokens.spacing.small
        width: parent.width
        height: 32

        Strip {
            id: chips

            anchors.left: parent.left
            anchors.right: colourRow.visible ? colourRow.left : parent.right
            anchors.rightMargin: Tokens.spacing.normal
            height: parent.height
            spacing: Tokens.spacing.small
            // Library: folders. Store: Wallhaven's filters, each a toggle or a
            // cycle ({ text, on, act }).
            model: root.rotating ? root.rotationChips : root.store ? root.storeChips : ["", ...Wallpapers.folders].map(f => ({
                        text: f ? f.charAt(0).toUpperCase() + f.slice(1) : "All",
                        on: Wallpapers.filterFolder === f,
                        act: () => Wallpapers.filterFolder = f
                    }))

            delegate: Chip {
                required property var modelData

                text: modelData.text
                selected: modelData.on
                opacity: modelData.disabled ? 0.4 : 1
                onClicked: {
                    if (!modelData.disabled)
                        modelData.act();
                }
            }
        }

        Row {
            id: colourRow

            visible: !root.rotating && !(root.store && root.live)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            // Colour: twelve hues, then black and white. Selecting rings it in
            // ink and quiets the rest (Ryoku's "colour as data").
            Repeater {
                model: 13

                Rectangle {
                    id: sw

                    required property int index
                    readonly property int bucket: index < 12 ? index : 99
                    readonly property int selectedColour: root.store ? root.studio.wallhaven.colour : Wallpapers.filterColour
                    readonly property bool on: selectedColour === bucket

                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    height: 22
                    radius: Tokens.rounding.small / 2
                    color: index < 12 ? root.swatches[index] : "transparent"
                    border.width: on ? 2 : index === 12 ? 1 : 0
                    border.color: Colours.palette.m3onSurface
                    opacity: on || swMouse.containsMouse || selectedColour === -1 ? 1 : 0.4
                    scale: on ? 1.15 : 1

                    // Black and white: half and half.
                    Rectangle {
                        visible: sw.index === 12
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: parent.radius
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0.49
                                color: "#111111"
                            }
                            GradientStop {
                                position: 0.51
                                color: "#eeeeee"
                            }
                        }
                    }

                    Behavior on scale {
                        Anim {
                            duration: Tokens.anim.fast
                        }
                    }

                    MouseArea {
                        id: swMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.store)
                                root.studio.wallhaven.colour = sw.on ? -1 : sw.bucket;
                            else
                                Wallpapers.filterColour = sw.on ? -1 : sw.bucket;
                        }
                    }
                }
            }

            Item {
                width: Tokens.spacing.small
                height: 1
            }

            IconButton {
                visible: !root.store
                anchors.verticalCenter: parent.verticalCenter
                icon: Wallpapers.filterTone === "light" ? "light_mode" : Wallpapers.filterTone === "dark" ? "dark_mode" : "contrast"
                size: 30
                filled: Wallpapers.filterTone !== ""
                onClicked: Wallpapers.filterTone = Wallpapers.filterTone === "" ? "dark" : Wallpapers.filterTone === "dark" ? "light" : ""
            }

            IconButton {
                visible: !root.store
                anchors.verticalCenter: parent.verticalCenter
                icon: "star"
                size: 30
                filled: Wallpapers.filterFavourites
                onClicked: Wallpapers.filterFavourites = !Wallpapers.filterFavourites
            }
        }
    }

    // ── The view ──
    Loader {
        id: viewLoader

        anchors.top: filters.bottom
        anchors.topMargin: Tokens.spacing.normal
        anchors.bottom: parent.bottom
        width: parent.width
        sourceComponent: Wallpapers.view === "slice" ? slices : Wallpapers.view === "mosaic" ? mosaic : strip
        onLoaded: Qt.callLater(root.centreOnCurrent)
    }

    EmptyState {
        anchors.centerIn: viewLoader
        visible: root.walls.length === 0
        icon: "image_search"
        title: root.store ? (root.shop.loading ? "Searching…" : root.shop.error || "Nothing matches") : Wallpapers.all.length === 0 ? "No wallpapers in ~/Pictures/Wallpapers" : "Nothing matches"
    }

    Component {
        id: strip

        StripView {
            model: root.walls
            onPicked: (i, close) => root.choose(close)
        }
    }

    Component {
        id: slices

        SliceView {
            model: root.walls
            onPicked: (i, close) => root.choose(close)
        }
    }

    Component {
        id: mosaic

        MosaicView {
            model: root.walls
            onPicked: (i, close) => root.choose(close)
        }
    }

    // The drawer is still growing when this loads: centre again once the
    // opening spring is done.
    Timer {
        running: true
        interval: 450
        onTriggered: root.centreOnCurrent()
    }
}
