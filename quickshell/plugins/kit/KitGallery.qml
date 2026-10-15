pragma ComponentBehavior: Bound

import QtQuick
import M3Shapes
import qs.config
import qs.services
import qs.components
import "../../components/written.js" as Written

// The kit's gallery (IPC `shell open kit`): every primitive, numbered, in
// its states, side by side, so the design can be reviewed and talked about
// by number ("4: the switch's thumb"). Controls here work, on local state.
Item {
    id: root

    // A numbered entry: its number and name over its specimens.
    component Entry: Column {
        id: entry

        property string num
        property string name
        property string note
        default property alias specimens: row.data

        width: parent?.width ?? 0
        spacing: Tokens.spacing.small

        Row {
            spacing: Tokens.spacing.small

            StyledText {
                text: entry.num
                color: Colours.palette.m3primary
                font.family: Tokens.font.mono
                font.pixelSize: Tokens.font.small
                font.weight: Font.DemiBold
            }
            StyledText {
                text: entry.name
                color: Colours.palette.m3onSurface
                font.pixelSize: Tokens.font.small
                font.weight: Font.DemiBold
            }
            StyledText {
                visible: entry.note !== ""
                text: "· " + entry.note
                color: Colours.palette.m3onSurfaceVariant
                font.pixelSize: Tokens.font.small
            }
        }

        Flow {
            id: row

            width: parent.width
            spacing: Tokens.spacing.large
        }
    }

    // One specimen: the thing over a small caption.
    component Spec: Column {
        id: spec

        property string caption
        default property alias content: holder.data

        spacing: 6

        Item {
            id: holder

            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
        }
        MicroLabel {
            text: spec.caption
        }
    }

    Scroller {
        id: scroll

        anchors.fill: parent
        anchors.margins: Tokens.spacing.large
        contentHeight: body.implicitHeight

        Column {
            id: body

            width: scroll.width
            spacing: Tokens.spacing.large * 1.5

            GlossTitle {
                text: "Kit"
                gloss: "器"
            }

            Entry {
                num: "1"
                name: "Surface"
                note: "the container; role × emphasis, paper levels"

                Repeater {
                    model: [0, 1, 2, 3, 4]

                    Spec {
                        required property int modelData

                        caption: "paper " + modelData
                        Surface {
                            level: parent.parent.modelData
                            outlined: true
                            width: 88
                            height: 56
                        }
                    }
                }
                Repeater {
                    model: ["primary", "secondary", "tertiary", "error"]

                    Row {
                        id: roleRow

                        required property string modelData

                        spacing: 8

                        Repeater {
                            model: ["soft", "strong", "ghost"]

                            Spec {
                                required property string modelData

                                caption: roleRow.modelData.slice(0, 3) + " " + modelData
                                Surface {
                                    id: s

                                    role: roleRow.modelData
                                    emphasis: parent.parent.modelData
                                    outlined: emphasis === "ghost"
                                    interactive: true
                                    width: 88
                                    height: 56

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: "Aa"
                                        color: s.ink
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Entry {
                num: "2"
                name: "IconButton"

                Spec {
                    caption: "tonal"
                    IconButton {
                        icon: "bolt"
                    }
                }
                Spec {
                    caption: "filled"
                    IconButton {
                        icon: "bolt"
                        filled: true
                    }
                }
                Spec {
                    caption: "caption"
                    IconButton {
                        icon: "brightness_6"
                        caption: "70"
                    }
                }
                Spec {
                    caption: "size 56"
                    IconButton {
                        icon: "play_arrow"
                        size: 56
                        filled: true
                    }
                }
            }

            Entry {
                num: "3"
                name: "Chip"

                Spec {
                    caption: "rest"
                    Chip {
                        text: "Nature"
                    }
                }
                Spec {
                    caption: "selected"
                    Chip {
                        text: "Nature"
                        selected: true
                    }
                }
                Spec {
                    caption: "icon · toggles"
                    Chip {
                        id: chipToggle

                        text: "Favourites"
                        icon: "star"
                        onClicked: selected = !selected
                    }
                }
            }

            Entry {
                num: "4"
                name: "StyledSwitch"

                Spec {
                    caption: "off"
                    StyledSwitch {
                        checked: false
                    }
                }
                Spec {
                    caption: "on"
                    StyledSwitch {
                        checked: true
                    }
                }
                Spec {
                    caption: "toggles"
                    StyledSwitch {
                        id: sw

                        onToggled: checked = !checked
                    }
                }
            }

            Entry {
                num: "5"
                name: "ButtonGroup"

                Spec {
                    caption: "pick one"
                    ButtonGroup {
                        id: bg

                        current: "normal"
                        model: [{
                                value: "reduced",
                                icon: "slow_motion_video",
                                label: "Reduced"
                            }, {
                                value: "normal",
                                icon: "motion_photos_on",
                                label: "Normal"
                            }, {
                                value: "brisk",
                                icon: "speed",
                                label: "Brisk"
                            }]
                        onSelected: v => current = v
                    }
                }
            }

            Entry {
                num: "6"
                name: "Tile"

                Spec {
                    caption: "off"
                    Tile {
                        width: 180
                        icon: "wifi"
                        label: "Wi-Fi"
                        sublabel: "Off"
                    }
                }
                Spec {
                    caption: "on · toggles"
                    Tile {
                        id: tile

                        width: 180
                        icon: "bluetooth"
                        label: "Bluetooth"
                        sublabel: checked ? "On" : "Off"
                        checked: true
                        onClicked: checked = !checked
                    }
                }
                Spec {
                    caption: "stacked"
                    Tile {
                        width: 120
                        stacked: true
                        icon: "dark_mode"
                        label: "Dark"
                        sublabel: "On"
                        checked: true
                    }
                }
            }

            Entry {
                num: "15"
                name: "Goo groups"
                note: "the bar's goo: hover follows, the selection flows and splits"

                Spec {
                    caption: "chip group · pick one"
                    ChipGroup {
                        current: "nature"
                        model: [{
                                value: "all",
                                label: "All"
                            }, {
                                value: "nature",
                                label: "Nature"
                            }, {
                                value: "city",
                                label: "City"
                            }, {
                                value: "anime",
                                label: "Anime",
                                icon: "auto_awesome"
                            }, {
                                value: "live",
                                label: "Live",
                                icon: "play_circle"
                            }]
                        onSelected: v => current = v
                    }
                }
                Spec {
                    caption: "tile grid · hover goo over toggles"
                    Item {
                        width: tiles.width
                        height: tiles.height

                        Grid {
                            id: tiles

                            columns: 3
                            spacing: Tokens.spacing.small

                            Repeater {
                                model: [["wifi", "Wi-Fi"], ["bluetooth", "Bluetooth"], ["dark_mode", "Dark"], ["do_not_disturb_on", "Quiet"], ["nightlight", "Night light"], ["coffee", "Awake"]]

                                Tile {
                                    required property var modelData
                                    required property int index

                                    width: 160
                                    icon: modelData[0]
                                    label: modelData[1]
                                    sublabel: checked ? "On" : "Off"
                                    checked: index % 2 === 0
                                    hoverLayer: false
                                    onClicked: checked = !checked
                                }
                            }
                        }

                        GooIndicator {
                            anchors.fill: tiles
                            hovered: {
                                for (let i = 0; i < tiles.children.length; i++) {
                                    const t = tiles.children[i];
                                    if (t.hovered)
                                        return t;
                                }
                                return null;
                            }
                            fill: Colours.palette.m3onSurface
                            strength: 0.08
                            radius: Tokens.rounding.normal
                        }
                    }
                }
            }

            Entry {
                num: "7"
                name: "ListRow"

                Spec {
                    caption: "rest"
                    ListRow {
                        width: 300
                        icon: "folder"
                        title: "Wallpapers"
                        subtitle: "753 pictures"
                    }
                }
                Spec {
                    caption: "a list · goo glides to the hovered and picked row"
                    Item {
                        width: 300
                        height: rows.height

                        property int picked: 1

                        GooIndicator {
                            id: listGoo

                            anchors.fill: rows
                            selected: rows.children[parent.picked] ?? null
                            hovered: {
                                for (let i = 0; i < rows.children.length; i++)
                                    if (rows.children[i].hovered)
                                        return rows.children[i];
                                return null;
                            }
                            fill: Colours.roleFill("secondary", "soft", 0)
                            radius: Tokens.rounding.normal
                        }

                        Column {
                            id: rows

                            width: parent.width

                            Repeater {
                                model: [["folder", "Wallpapers", "753 pictures"], ["play_circle", "Live", "6 videos"], ["star", "Favourites", "12 picked"], ["history", "Recent", "this week"]]

                                ListRow {
                                    id: lr

                                    required property var modelData
                                    required property int index

                                    width: rows.width
                                    icon: modelData[0]
                                    title: modelData[1]
                                    subtitle: modelData[2]
                                    hoverLayer: false
                                    baseInk: listGoo.covers(lr) ? Colours.roleInk("secondary", "soft") : Colours.roleInk("paper", "soft")
                                    baseSubInk: listGoo.covers(lr) ? Colours.roleSubInk("secondary", "soft") : Colours.roleSubInk("paper", "soft")
                                    onClicked: rows.parent.picked = index
                                }
                            }
                        }
                    }
                }
                Spec {
                    caption: "highlighted"
                    ListRow {
                        width: 300
                        icon: "folder_open"
                        iconFill: 1
                        title: "Live"
                        subtitle: "6 videos"
                        highlighted: true
                    }
                }
            }

            Entry {
                num: "8"
                name: "StyledSlider"

                Spec {
                    caption: "icon · drag"
                    StyledSlider {
                        id: sl

                        width: 260
                        icon: "volume_up"
                        value: 0.6
                        onMoved: v => value = v
                    }
                }
                Spec {
                    caption: "empty"
                    StyledSlider {
                        width: 260
                        value: 0
                    }
                }
            }

            Entry {
                num: "9"
                name: "TextField"

                Spec {
                    caption: "placeholder"
                    TextField {
                        width: 260
                        placeholder: "Search wallpapers"
                    }
                }
                Spec {
                    caption: "filled"
                    TextField {
                        width: 260
                        text: "kanagawa"
                    }
                }
                Spec {
                    caption: "password"
                    TextField {
                        width: 200
                        echoMode: TextInput.Password
                        text: "secret"
                    }
                }
            }

            Entry {
                num: "17"
                name: "Typing"
                note: "pick any together (the shell's setting, Appearance → Typing); click a field, type, jump around"

                Spec {
                    caption: "styles on"
                    Row {
                        spacing: Tokens.spacing.small

                        Repeater {
                            model: [["goo", "Goo caret", "water_drop"], ["trail", "Caret trail", "swipe_right_alt"], ["ink", "Ink letters", "ink_pen"], ["brush", "Brush line", "brush"]]

                            Chip {
                                required property var modelData

                                text: modelData[1]
                                icon: modelData[2]
                                selected: Tokens.typing.indexOf(modelData[0]) >= 0
                                onClicked: {
                                    const on = Tokens.typing.filter(v => v !== modelData[0]);
                                    Settings.set("typing", selected ? on : on.concat([modelData[0]]));
                                }
                            }
                        }
                    }
                }
                Spec {
                    caption: "field"
                    TextField {
                        id: tfDemo

                        width: 300
                        placeholder: "Type here"
                    }
                }
                Spec {
                    caption: "password · seals melting into dots"
                    TextField {
                        id: tfSeal

                        width: 260
                        placeholder: "Password"
                        echoMode: TextInput.Password
                        seals: true
                    }
                }
            }

            Entry {
                num: "18"
                name: "Text motion"
                note: "only for text that changes now and then"

                Spec {
                    caption: "roll · numbers"
                    Row {
                        spacing: Tokens.spacing.normal

                        property int value: 64

                        IconButton {
                            id: down

                            icon: "remove"
                            onClicked: parent.value = Math.max(0, parent.value - (parent.value % 10 === 0 ? 7 : 1))
                        }
                        RollText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.value + "%"
                            font.pixelSize: Tokens.font.hero
                        }
                        IconButton {
                            icon: "add"
                            onClicked: parent.value = Math.min(100, parent.value + (parent.value % 10 === 9 ? 1 : 3))
                        }
                    }
                }
                Spec {
                    caption: "ink-swap · labels"
                    Row {
                        spacing: Tokens.spacing.normal

                        property int i: 0
                        readonly property var labels: ["Off", "On", "Paused", "Kabhi Kabhi Aditi", "Main Haar Giyan"]

                        IconButton {
                            icon: "sync"
                            onClicked: parent.i = (parent.i + 1) % parent.labels.length
                        }
                        InkSwap {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 200
                            text: parent.labels[parent.i]
                            font.pixelSize: Tokens.font.value
                        }
                    }
                }
                Spec {
                    caption: "write-on · headings (first show per session)"
                    Row {
                        spacing: Tokens.spacing.normal

                        IconButton {
                            icon: "replay"
                            onClicked: {
                                delete Written.seen[heading.text + "|" + heading.gloss];
                                heading.write();
                            }
                        }
                        GlossTitle {
                            id: heading

                            anchors.verticalCenter: parent.verticalCenter
                            text: "Notifications"
                            gloss: "传音"
                            writeOn: true
                        }
                    }
                }
            }

            Entry {
                num: "16"
                name: "Text area"
                note: "the same typing styles: Enter, Ctrl+arrows, Home/End or a click to cut"

                Spec {
                    caption: "grows with its text, then scrolls"
                    TextArea {
                        width: 520
                        placeholder: "Write anything"
                        text: "The brush moves before the thought.\nClick anywhere, or press Enter, Home, End,\nCtrl+Left / Ctrl+Right to watch the caret cut across."
                    }
                }
            }

            Entry {
                num: "10"
                name: "Progress"
                note: "LinearProgress, CircularProgress, Gauge, Sparkline"

                Spec {
                    caption: "linear 0.6"
                    LinearProgress {
                        width: 200
                        value: 0.6
                    }
                }
                Spec {
                    caption: "circular 0.4"
                    CircularProgress {
                        value: 0.4
                    }
                }
                Spec {
                    caption: "gauge"
                    Gauge {
                        value: 0.42
                        text: "42%"
                        label: "CPU"
                    }
                }
                Spec {
                    caption: "gauge · rolls (click)"
                    Gauge {
                        id: rollGauge

                        property int pct: 76

                        value: pct / 100
                        text: pct + "%"
                        label: "BAT"
                        roll: true

                        TapHandler {
                            onTapped: rollGauge.pct = rollGauge.pct > 50 ? rollGauge.pct - 23 : rollGauge.pct + 41
                        }
                    }
                }
                Spec {
                    caption: "gauge warn"
                    Gauge {
                        value: 0.91
                        text: "91%"
                        label: "RAM"
                        warn: true
                    }
                }
                Spec {
                    caption: "sparkline"
                    Sparkline {
                        width: 160
                        height: 48
                        values: [0.2, 0.35, 0.3, 0.6, 0.45, 0.7, 0.5, 0.8, 0.65, 0.4]
                        max: 1
                    }
                }
            }

            Entry {
                num: "11"
                name: "Type"
                note: "GlossTitle, SectionLabel, MicroLabel, Seal, Hairline"

                Spec {
                    caption: "gloss title"
                    GlossTitle {
                        text: "Sound"
                        gloss: "声音"
                    }
                }
                Spec {
                    caption: "section label"
                    SectionLabel {
                        text: "Output"
                    }
                }
                Spec {
                    caption: "micro label"
                    MicroLabel {
                        text: "48 kHz"
                    }
                }
                Spec {
                    caption: "seal"
                    Seal {
                        glyph: "印"
                        size: 28
                    }
                }
                Spec {
                    caption: "hairline"
                    Hairline {
                        width: 160
                    }
                }
            }

            Entry {
                num: "12"
                name: "ShapeBadge"

                Spec {
                    caption: "clamshell"
                    ShapeBadge {
                        implicitSize: 56
                        shape: MaterialShape.ClamShell
                        role: "primary"
                        icon: "schedule"
                    }
                }
                Spec {
                    caption: "cookie"
                    ShapeBadge {
                        implicitSize: 56
                        shape: MaterialShape.Cookie4Sided
                        role: "tertiary"
                        icon: "memory"
                    }
                }
                Spec {
                    caption: "live · breathes"
                    ShapeBadge {
                        implicitSize: 56
                        shape: MaterialShape.Cookie9Sided
                        role: "primary"
                        icon: "music_note"
                        live: true
                    }
                }
                Spec {
                    caption: "sunny"
                    ShapeBadge {
                        implicitSize: 56
                        shape: MaterialShape.Sunny
                        role: "secondary"
                        icon: "bolt"
                    }
                }
            }

            Entry {
                num: "13"
                name: "Sheet · PanelHeader"

                Spec {
                    caption: "panel header"
                    PanelHeader {
                        width: 420
                        icon: "volume_up"
                        title: "Sound"
                        gloss: "声音"
                        subtitle: "Speakers · 60%"
                    }
                }
                Spec {
                    caption: "sheet"
                    Sheet {
                        width: 420
                        title: "Output"
                        gloss: "输出"
                        eyebrow: "Device"

                        StyledText {
                            text: "A sheet's content sits here."
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }
                }
            }

            Entry {
                num: "14"
                name: "EmptyState"

                Spec {
                    caption: "with action"
                    EmptyState {
                        width: 360
                        icon: "notifications_off"
                        title: "All quiet"
                        hint: "Nothing new since you looked."
                        actionText: "Open settings"
                    }
                }
            }
        }
    }
}
