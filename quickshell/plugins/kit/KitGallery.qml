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
                num: "21"
                name: "Motion feel"
                note: "press play; pick them in Settings → Appearance (Panels' / Controls' spring, Contents)"

                // ── Springs: one move, three characters ──
                Spec {
                    caption: "springs"
                    Column {
                        id: springs

                        property bool across: false

                        spacing: Tokens.spacing.small

                        IconButton {
                            icon: "play_arrow"
                            onClicked: springs.across = !springs.across
                        }

                        Repeater {
                            // The shell's presets (Appearance → Panels' / Controls' spring).
                            model: ["calm", "natural", "lively", "snappy", "crisp"].map(k => [k, Tokens.springPresets[k][0], Tokens.springPresets[k][1]])

                            Item {
                                id: lane

                                required property var modelData

                                width: 300
                                height: 34

                                MicroLabel {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: lane.modelData[0]
                                }

                                StyledRect {
                                    x: 60
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 236
                                    height: 4
                                    radius: 2
                                    color: Colours.roleFill("paper", "soft", 4)
                                }

                                Surface {
                                    property real pos: springs.across ? 1 : 0

                                    x: 60 + pos * 206
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 30
                                    height: 30
                                    role: "primary"
                                    emphasis: "strong"

                                    Behavior on pos {
                                        SpringAnimation {
                                            spring: Tokens.springK(lane.modelData[1])
                                            damping: Tokens.dampK(lane.modelData[2])
                                            epsilon: 0.002
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── A panel's contents arriving: together, staggered, inked ──
                Spec {
                    caption: "contents"
                    Row {
                        id: arrive

                        // Bumped to play all three again.
                        property int run: 0

                        spacing: Tokens.spacing.normal

                        IconButton {
                            icon: "play_arrow"
                            onClicked: arrive.run++
                        }

                        Repeater {
                            model: ["together", "stagger", "ink"]

                            Surface {
                                id: mock

                                required property string modelData
                                // 0 → 1 over the opening.
                                property real t: 1

                                width: 170
                                height: 190
                                level: 2
                                outlined: true

                                Connections {
                                    target: arrive

                                    function onRunChanged(): void {
                                        play.restart();
                                    }
                                }
                                NumberAnimation {
                                    id: play

                                    target: mock
                                    property: "t"
                                    from: 0
                                    to: 1
                                    duration: Tokens.dur(mock.modelData === "together" ? 320 : 620)
                                }

                                Column {
                                    x: 10
                                    y: 10
                                    width: parent.width - 20
                                    spacing: 6
                                    // Together: the whole panel soaks in at once.
                                    opacity: mock.modelData === "together" ? Math.min(1, mock.t * 1.4) : 1
                                    scale: mock.modelData === "together" ? 0.97 + 0.03 * mock.t : 1

                                    MicroLabel {
                                        text: mock.modelData
                                    }

                                    Repeater {
                                        model: 5

                                        Item {
                                            id: rowItem

                                            required property int index
                                            // This row's own progress (staggered by 45 ms a row).
                                            readonly property real local: Math.max(0, Math.min(1, (mock.t * 620 - index * 45) / 300))
                                            readonly property real eased: 1 - Math.pow(1 - local, 3)

                                            width: parent.width
                                            height: 26

                                            Item {
                                                height: parent.height
                                                clip: mock.modelData === "ink"
                                                // Ink: brushed in from the left.
                                                width: mock.modelData === "ink" ? parent.width * rowItem.eased : parent.width

                                                StyledRect {
                                                    width: rowItem.width
                                                    height: rowItem.height
                                                    radius: Tokens.rounding.small
                                                    color: Colours.roleFill(rowItem.index === 0 ? "secondary" : "paper", "soft", 4)
                                                    // Stagger: each row rises in after the last.
                                                    opacity: mock.modelData === "stagger" ? rowItem.eased : 1
                                                    y: mock.modelData === "stagger" ? (1 - rowItem.eased) * 10 : 0

                                                    StyledRect {
                                                        x: 8
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: 40 + (rowItem.index * 23) % 50
                                                        height: 6
                                                        radius: 3
                                                        color: Colours.roleSubInk("paper", "soft")
                                                        opacity: 0.6
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Entry {
                num: "20"
                name: "Reorder"
                note: "drag a row by its grip; the others make room, goo marks where it lands"

                Spec {
                    caption: "pinned"
                    ReorderList {
                        id: reorder

                        width: 320
                        model: ["Wi-Fi password", "ssh key path", "Meeting link", "Address", "Recipe"]
                        delegate: Component {
                            ListRow {
                                property var modelData
                                property int index

                                icon: "push_pin"
                                iconFill: 1
                                title: modelData ?? ""
                                subtitle: "pinned " + ((index ?? 0) + 1)
                                hoverLayer: false
                            }
                        }
                        onMoved: (a, b) => {
                            const m = model.slice();
                            m.splice(b, 0, m.splice(a, 1)[0]);
                            model = m;
                        }
                    }
                }
            }

            Entry {
                num: "19"
                name: "New controls"
                note: "checkbox, radio, stepper, swatch, select, menu, tooltip, dialog"

                Spec {
                    caption: "checkbox"
                    Column {
                        spacing: Tokens.spacing.small

                        Checkbox {
                            text: "Show seconds"
                            checked: true
                            onToggled: checked = !checked
                        }
                        Checkbox {
                            text: "Pause on battery"
                            onToggled: checked = !checked
                        }
                    }
                }
                Spec {
                    caption: "radio · the dot flows"
                    RadioGroup {
                        current: "week"
                        model: [{
                                value: "day",
                                label: "Every day"
                            }, {
                                value: "week",
                                label: "Every week",
                                sublabel: "Mondays, 9:00"
                            }, {
                                value: "never",
                                label: "Never"
                            }]
                        onSelected: v => current = v
                    }
                }
                Spec {
                    caption: "stepper · hold to run"
                    Stepper {
                        value: 15
                        from: 1
                        to: 120
                        unit: " min"
                        onMoved: v => value = v
                    }
                }
                Spec {
                    caption: "swatches"
                    Row {
                        id: swatches

                        property int picked: 2

                        spacing: Tokens.spacing.small

                        Repeater {
                            model: ["#e680a1", "#df8f48", "#9ab04b", "#06bfa8", "#4baeed", "#b191ea"]

                            Swatch {
                                required property string modelData
                                required property int index

                                colour: modelData
                                picked: swatches.picked === index
                                onClicked: swatches.picked = index
                            }
                        }
                    }
                }
                Spec {
                    caption: "select"
                    Select {
                        current: "screen"
                        model: [{
                                value: "screen",
                                text: "Screen quality",
                                icon: "monitor"
                            }, {
                                value: "original",
                                text: "Original",
                                icon: "high_quality"
                            }, {
                                value: "battery",
                                text: "Battery saver",
                                icon: "battery_saver"
                            }]
                        onSelected: v => current = v
                    }
                }
                Spec {
                    caption: "menu · click, or right-click the box"
                    Row {
                        spacing: Tokens.spacing.normal

                        IconButton {
                            id: more

                            icon: "more_vert"
                            onClicked: moreMenu.show()

                            Tooltip {
                                text: "More"
                            }
                        }
                        Surface {
                            id: rightBox

                            width: 120
                            height: 40
                            level: 2
                            outlined: true

                            StyledText {
                                anchors.centerIn: parent
                                text: "right-click"
                                color: Colours.palette.m3onSurfaceVariant
                                font.pixelSize: Tokens.font.small
                            }
                            TapHandler {
                                acceptedButtons: Qt.RightButton
                                onTapped: p => moreMenu.popup(rightBox, p.position)
                            }
                        }
                        Menu {
                            id: moreMenu

                            from: more
                            model: [{
                                    value: "pin",
                                    text: "Pin",
                                    icon: "push_pin"
                                }, {
                                    value: "copy",
                                    text: "Copy",
                                    icon: "content_copy"
                                }, {
                                    value: "forget",
                                    text: "Forget",
                                    icon: "delete",
                                    danger: true
                                }]
                            onPicked: v => {
                                if (v === "forget")
                                    confirm.show();
                            }
                        }
                    }
                }
                Spec {
                    caption: "dialog · tooltip on hover"
                    IconButton {
                        id: askBtn

                        icon: "delete"
                        onClicked: confirm.show()

                        Tooltip {
                            text: "Forget this device"
                        }
                        Dialog {
                            id: confirm

                            from: askBtn
                            title: "Forget Pixel Buds?"
                            text: "You'll need to pair them again to use them."
                            confirmText: "Forget"
                            danger: true
                        }
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
