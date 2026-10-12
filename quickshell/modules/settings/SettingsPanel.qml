pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.components

// The Settings panel (Mod+S): a page for every feature's declared settings
// (Settings.pages), built from the declarations, so a new feature gets its
// page without UI of its own. The pages on the left; the page's settings on
// the right, grouped by section, each row made of the panels' primitives. A
// changed setting can go back to its default (the reset button beside it).
Panel {
    id: root

    // Every feature that declares settings. Services start when first used,
    // so the panel starts them: each one's page is then registered.
    readonly property var features: [Tokens, ShellState, Theme, Wallpapers, Display, Weather, Time, Power, Session]

    readonly property var page: Settings.pages.find(p => p.name === ShellState.settingsPage) ?? Settings.pages[0] ?? null

    // A number as its setting reads it.
    function readNumber(item: var, v: real): string {
        if (v === 0 && item.zeroLabel)
            return item.zeroLabel;
        if (item.format === "duration") {
            const t = Math.round(v);
            if (t >= 3600)
                return `${Math.floor(t / 3600)} h${t % 3600 ? ` ${Math.round(t % 3600 / 60)} min` : ""}`;
            if (t >= 60)
                return t % 60 ? `${Math.floor(t / 60)}:${String(t % 60).padStart(2, "0")} min` : `${t / 60} min`;
            return `${t} s`;
        }
        return `${v}${item.unit}`;
    }

    icon: "tune"
    title: "Settings"
    gloss: "设置"
    subtitle: page?.description ?? ""

    Item {
        width: parent.width
        height: 480

        // ── The pages (a Strip: it scrolls once they outgrow the panel) ──
        Strip {
            id: list

            width: 200
            height: parent.height
            orientation: ListView.Vertical
            spacing: Tokens.spacing.tiny
            model: Settings.pages

            delegate: ListRow {
                required property var modelData

                width: list.width
                icon: modelData.icon
                iconFill: highlighted ? 1 : 0
                title: modelData.title
                subtitle: modelData.gloss
                highlighted: modelData === root.page
                onClicked: ShellState.settingsPage = modelData.name
            }
        }

        Hairline {
            id: rule

            anchors.left: list.right
            anchors.leftMargin: Tokens.spacing.large
            vertical: true
            height: parent.height
        }

        // ── The page ──
        Scroller {
            id: flick

            anchors.left: rule.right
            anchors.leftMargin: Tokens.spacing.large
            anchors.right: parent.right
            height: parent.height
            contentHeight: items.implicitHeight
            clip: true

            Column {
                id: items

                width: flick.width
                spacing: Tokens.spacing.large

                Repeater {
                    model: root.page ? Settings.itemsOf(root.page.name) : []

                    SettingRow {
                        required property var modelData

                        item: modelData
                        values: Settings.valuesOf(root.page.name)
                        width: items.width
                    }
                }
            }
        }
    }

    // One setting, from the panels' own primitives: a choice is a
    // ButtonGroup, on/off a ListRow with a StyledSwitch, text a TextField, a
    // number a StyledSlider, each under a Sheet heading (the reset button
    // is its trailing action, while the setting differs from its default).
    // A section starts with its eyebrow; hairlines part the rows.
    component SettingRow: Column {
        id: row

        required property var item
        required property var values
        required property int index
        readonly property var value: values[item.key]
        readonly property bool modified: item.key in Settings.values && JSON.stringify(Settings.values[item.key]) !== JSON.stringify(item.def)

        visible: item.shown
        spacing: Tokens.spacing.normal

        Hairline {
            visible: row.index > 0 && row.item.section === ""
            width: row.width
        }

        SectionLabel {
            visible: row.item.section !== ""
            text: row.item.section
            topPadding: row.index > 0 ? Tokens.spacing.large : 0
        }

        // On / off: the row is the control.
        ListRow {
            visible: row.item.kind === "toggle"
            width: row.width
            icon: row.item.icon
            iconFill: row.value === true ? 1 : 0
            title: row.item.label
            subtitle: row.item.description
            onClicked: Settings.set(row.item.key, row.value !== true)

            StyledSwitch {
                checked: row.value === true
                onToggled: Settings.set(row.item.key, row.value !== true)
            }
        }

        Sheet {
            visible: row.item.kind !== "toggle"
            width: row.width
            title: row.item.label
            trailing: [
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.item.kind === "number"
                    text: root.readNumber(row.item, row.value)
                    color: Colours.palette.m3onSurfaceVariant
                    font.family: Tokens.font.mono
                    font.pixelSize: Tokens.font.small
                },
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.modified
                    size: 32
                    icon: "restart_alt"
                    onClicked: Settings.reset(row.item.key)
                }
            ]

            StyledText {
                width: parent.width
                visible: text !== ""
                text: row.item.description
                color: Colours.palette.m3onSurfaceVariant
                font.pixelSize: Tokens.font.small
                wrapMode: Text.WordWrap
            }

            Loader {
                width: parent.width
                active: row.item.kind !== "toggle"
                sourceComponent: row.item.kind === "text" ? textField : row.item.kind === "number" ? number : row.item.kind === "multi" ? multi : choice
            }
        }

        // Any number of choices: chips that toggle.
        Component {
            id: multi

            Flow {
                width: row.width
                spacing: Tokens.spacing.small

                Repeater {
                    model: row.item.options

                    Chip {
                        required property var modelData
                        readonly property var chosen: Array.isArray(row.value) ? row.value : []

                        icon: modelData.icon ?? ""
                        text: modelData.label
                        selected: chosen.includes(modelData.value)
                        onClicked: Settings.set(row.item.key, selected ? chosen.filter(v => v !== modelData.value) : chosen.concat([modelData.value]))
                    }
                }
            }
        }

        // A few choices: a ButtonGroup; many: chips that wrap.
        Component {
            id: choice

            Loader {
                sourceComponent: row.item.options.length > 5 ? chips : group
            }
        }

        Component {
            id: group

            ButtonGroup {
                width: row.width
                model: row.item.options
                current: row.value
                onSelected: v => Settings.set(row.item.key, v)
            }
        }

        Component {
            id: chips

            Flow {
                width: row.width
                spacing: Tokens.spacing.small

                Repeater {
                    model: row.item.options

                    Chip {
                        required property var modelData

                        icon: modelData.icon ?? ""
                        text: modelData.label
                        selected: row.value === modelData.value
                        onClicked: Settings.set(row.item.key, modelData.value)
                    }
                }
            }
        }

        Component {
            id: number

            StyledSlider {
                value: (row.value - row.item.min) / Math.max(1e-6, row.item.max - row.item.min)
                onMoved: v => {
                    const raw = row.item.min + v * (row.item.max - row.item.min);
                    const places = (String(row.item.step).split(".")[1] ?? "").length;
                    Settings.set(row.item.key, Number((Math.round(raw / row.item.step) * row.item.step).toFixed(places)));
                }
            }
        }

        // Text is kept on Enter, or when the panel closes or the page changes.
        Component {
            id: textField

            TextField {
                function commit(): void {
                    if (text !== row.value)
                        Settings.set(row.item.key, text);
                }

                text: row.value ?? ""
                placeholder: row.item.placeholder
                echoMode: row.item.secret ? TextInput.Password : TextInput.Normal
                onAccepted: commit()
                Component.onDestruction: commit()
            }
        }
    }
}
