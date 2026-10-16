pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import Nafeel
import qs.config
import qs.services
import qs.components

// The launcher's results (services/Launcher.qml): every provider's, ranked;
// with Tab, the selected one's actions instead.
Item {
    id: root

    required property var cc

    // The matched characters of a title, in the accent.
    function marked(r: var): string {
        const t = r.title ?? "";
        if (Launcher.query === "" || r.highlight === false)
            return t.replace(/&/g, "&amp;").replace(/</g, "&lt;");
        return Fuzzy.highlight(t, Launcher.query, `<font color="${Colours.palette.m3primary}">`, "</font>");
    }

    // The selected result's actions (Tab): what it is, then each action.
    Column {
        anchors.fill: parent
        visible: Launcher.actionsOf !== null
        spacing: 2

        StyledText {
            width: parent.width
            bottomPadding: Tokens.spacing.small
            text: `${Launcher.actionsOf?.title ?? ""}   ·   Esc or Shift+Tab goes back`
            color: Colours.palette.m3onSurfaceVariant
            font.pixelSize: Tokens.font.small
            elide: Text.ElideRight
        }

        Repeater {
            model: Launcher.actionsOf?.actions ?? []

            delegate: Row {
                id: action

                required property var modelData
                required property int index

                width: parent.width
                height: 48

                StyledRect {
                    width: parent.width
                    height: parent.height
                    radius: Tokens.rounding.normal
                    color: action.index === Launcher.actionSelected ? Colours.palette.m3secondaryContainer : actionHover.hovered ? Colours.palette.m3surfaceContainerHigh : "transparent"

                    MaterialIcon {
                        id: actionIcon

                        anchors.left: parent.left
                        anchors.leftMargin: Tokens.spacing.large
                        anchors.verticalCenter: parent.verticalCenter
                        text: action.modelData.icon || "chevron_right"
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    StyledText {
                        anchors.left: actionIcon.right
                        anchors.leftMargin: Tokens.spacing.normal
                        anchors.verticalCenter: parent.verticalCenter
                        text: action.modelData.label
                        color: action.index === Launcher.actionSelected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                        font.pixelSize: Tokens.font.row
                    }

                    HoverHandler {
                        id: actionHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: {
                            Launcher.actionSelected = action.index;
                            Launcher.activate(false);
                        }
                    }
                }
            }
        }
    }

    // The preview card beside the results: while something's typed.
    readonly property bool preview: Launcher.actionsOf === null && Launcher.query !== "" && Launcher.results.length > 0 && Settings.values["launcher.preview"] !== false

    LauncherPreview {
        id: previewCard

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 272
        visible: root.preview
    }

    ListView {
        id: list

        visible: Launcher.actionsOf === null
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.right: root.preview ? previewCard.left : parent.right
        anchors.rightMargin: root.preview ? Tokens.spacing.normal : 0
        clip: true
        spacing: 2
        model: Launcher.results
        currentIndex: Launcher.selected
        highlightMoveDuration: 0
        boundsBehavior: Flickable.StopAtBounds
        reuseItems: true

        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

        StyledText {
            anchors.centerIn: parent
            visible: list.count === 0
            text: Launcher.query === "" ? "" : `Nothing for “${Launcher.query}”`
            color: Colours.palette.m3onSurfaceVariant
        }

        delegate: StyledRect {
            id: row

            required property var modelData
            required property int index
            readonly property bool current: index === Launcher.selected
            readonly property bool asking: current && !!modelData.confirm && Launcher.confirming === (modelData.key ?? modelData.title)

            width: list.width
            height: 56
            radius: Tokens.rounding.normal
            color: asking ? Colours.palette.m3errorContainer : current ? Colours.palette.m3secondaryContainer : hover.hovered ? Colours.palette.m3surfaceContainerHigh : "transparent"

            // An app's (or window's) icon, else a Material Symbol.
            Item {
                id: lead

                anchors.left: parent.left
                anchors.leftMargin: Tokens.spacing.normal
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                height: 36

                IconImage {
                    anchors.fill: parent
                    visible: !!row.modelData.image
                    source: !row.modelData.image ? "" : row.modelData.image.startsWith("/") || row.modelData.image.includes("://") ? row.modelData.image : Quickshell.iconPath(row.modelData.image, "application-x-executable")
                }

                // An emoji (or any text) as the icon, large.
                StyledText {
                    anchors.centerIn: parent
                    visible: !!row.modelData.glyph
                    text: row.modelData.glyph ?? ""
                    font.pixelSize: 26
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: !row.modelData.image && !row.modelData.glyph
                    text: row.modelData.icon || "search"
                    size: 24
                    color: row.asking ? Colours.palette.m3onErrorContainer : row.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                }
            }

            Column {
                anchors.left: lead.right
                anchors.leftMargin: Tokens.spacing.normal
                anchors.right: tag.left
                anchors.rightMargin: Tokens.spacing.normal
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    width: parent.width
                    text: root.marked(row.modelData)
                    textFormat: Text.StyledText
                    color: row.asking ? Colours.palette.m3onErrorContainer : row.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                    font.pixelSize: Tokens.font.row
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width
                    visible: text !== ""
                    text: row.asking ? `Press Enter again to ${row.modelData.confirm.toLowerCase()}` : row.modelData.subtitle ?? ""
                    color: row.asking ? Colours.palette.m3onErrorContainer : row.current ? Qt.alpha(Colours.palette.m3onSecondaryContainer, 0.8) : Colours.palette.m3onSurfaceVariant
                    font.pixelSize: Tokens.font.small
                    elide: Text.ElideRight
                }
            }

            // Where it's from; on the selected row, what the keys do.
            StyledText {
                id: tag

                anchors.right: parent.right
                anchors.rightMargin: Tokens.spacing.large
                anchors.verticalCenter: parent.verticalCenter
                text: row.current ? (row.modelData.actions?.length ? "↵   ⇧↵   ⇥ more" : "↵") : row.modelData.provider ?? ""
                color: row.current ? Qt.alpha(Colours.palette.m3onSecondaryContainer, 0.75) : Colours.palette.m3outline
                font.family: Tokens.font.mono
                font.pixelSize: Tokens.font.micro
                font.letterSpacing: 0.6
            }

            HoverHandler {
                id: hover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: {
                    Launcher.selected = row.index;
                    Launcher.activate(false);
                }
            }
        }
    }
}
