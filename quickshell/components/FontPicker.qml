pragma ComponentBehavior: Bound

import QtQuick
import Nafeel
import qs.config
import qs.services

// A font picker: the current font shown in itself; opened, a search field and
// the installed families, each drawn in its own typeface, fuzzy-filtered as
// you type. Up / Down move, Enter picks, Esc closes; a click picks too.
// `fixed` lists the fixed-width families only.
//
//   FontPicker { value: "Noto Sans"; onPicked: f => … }
Item {
    id: root

    property string value
    property bool fixed: false
    // What the sample line says.
    property string sample: "The quick brown fox"
    property bool open: false
    signal picked(string family)

    readonly property var families: fixed ? FontList.mono : FontList.all
    property string query: ""
    readonly property var shown: {
        const q = query.trim();
        if (q === "")
            return families;
        const s = Fuzzy.scores(families, q);
        return families.map((f, i) => [f, s[i]]).filter(p => p[1] > 0).sort((a, b) => b[1] - a[1]).map(p => p[0]);
    }
    property int current: 0

    implicitWidth: 360
    implicitHeight: head.height + (open ? Tokens.spacing.small + search.height + Tokens.spacing.small + listArea.height : 0)

    function toggle(): void {
        open = !open;
        if (open) {
            FontList.want();
            query = "";
            search.text = "";
            current = Math.max(0, shown.indexOf(value));
            search.focusInput();
            list.positionViewAtIndex(current, ListView.Center);
        }
    }

    function pick(family: string): void {
        root.picked(family);
        open = false;
    }

    // The control: the font, in itself, and its sample.
    StyledRect {
        id: head

        width: parent.width
        height: 44
        radius: Tokens.rounding.small
        color: Colours.palette.m3surfaceContainerHighest
        border.width: root.open ? 2 : 0
        border.color: Colours.palette.m3primary

        StyledText {
            anchors.left: parent.left
            anchors.leftMargin: Tokens.spacing.normal
            anchors.right: arrow.left
            anchors.rightMargin: Tokens.spacing.normal
            anchors.verticalCenter: parent.verticalCenter
            text: root.value
            elide: Text.ElideRight
            font.family: root.value
            font.pixelSize: 15
        }

        MaterialIcon {
            id: arrow

            anchors.right: parent.right
            anchors.rightMargin: Tokens.spacing.normal
            anchors.verticalCenter: parent.verticalCenter
            text: root.open ? "expand_less" : "expand_more"
            color: Colours.palette.m3onSurfaceVariant
        }

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: root.toggle()
        }
    }

    TextField {
        id: search

        anchors.top: head.bottom
        anchors.topMargin: Tokens.spacing.small
        width: parent.width
        visible: root.open
        placeholder: root.fixed ? "Search fixed-width fonts" : "Search fonts"
        onTextChanged: {
            root.query = text;
            root.current = 0;
            list.positionViewAtBeginning();
        }
        keyFilter: event => {
            const n = root.shown.length;
            if (event.key === Qt.Key_Down || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_N)) {
                root.current = Math.min(n - 1, root.current + 1);
            } else if (event.key === Qt.Key_Up || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_P)) {
                root.current = Math.max(0, root.current - 1);
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (root.shown[root.current])
                    root.pick(root.shown[root.current]);
            } else if (event.key === Qt.Key_Escape) {
                root.open = false;
            } else {
                return;
            }
            event.accepted = true;
            list.positionViewAtIndex(root.current, ListView.Contain);
        }
    }

    // The families, each in its own typeface.
    StyledRect {
        id: listArea

        anchors.top: search.bottom
        anchors.topMargin: Tokens.spacing.small
        width: parent.width
        height: 264
        visible: root.open
        radius: Tokens.rounding.small
        color: Colours.palette.m3surfaceContainer
        clip: true

        ListView {
            id: list

            anchors.fill: parent
            anchors.margins: 4
            model: root.shown
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            reuseItems: true

            StyledText {
                anchors.centerIn: parent
                visible: list.count === 0
                text: root.families.length === 0 ? "Reading the fonts…" : "No font matches"
                color: Colours.palette.m3onSurfaceVariant
            }

            delegate: StyledRect {
                id: row

                required property string modelData
                required property int index
                readonly property bool selected: index === root.current

                width: list.width
                height: 44
                radius: Tokens.rounding.small
                color: selected ? Colours.palette.m3secondaryContainer : hover.hovered ? Colours.palette.m3surfaceContainerHigh : "transparent"

                StyledText {
                    id: label

                    anchors.left: parent.left
                    anchors.leftMargin: Tokens.spacing.normal
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData
                    font.family: row.modelData
                    font.pixelSize: 15
                    color: row.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                }

                StyledText {
                    anchors.left: label.right
                    anchors.leftMargin: Tokens.spacing.normal
                    anchors.right: tick.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.sample
                    elide: Text.ElideRight
                    font.family: row.modelData
                    font.pixelSize: 12
                    color: Colours.palette.m3onSurfaceVariant
                    opacity: 0.8
                }

                MaterialIcon {
                    id: tick

                    anchors.right: parent.right
                    anchors.rightMargin: Tokens.spacing.normal
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.modelData === root.value
                    text: "check"
                    size: 18
                    color: Colours.palette.m3primary
                }

                HoverHandler {
                    id: hover

                    cursorShape: Qt.PointingHandCursor
                    onPointChanged: if (hovered) root.current = row.index
                }

                TapHandler {
                    onTapped: root.pick(row.modelData)
                }
            }
        }
    }
}
