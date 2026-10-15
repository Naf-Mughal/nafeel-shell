pragma ComponentBehavior: Bound

import QtQuick
import M3Shapes
import qs.config
import qs.services
import qs.components

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
