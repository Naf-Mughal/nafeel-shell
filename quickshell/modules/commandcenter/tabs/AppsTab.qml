pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// The launcher: apps matching the search (all of them when it's empty), or
// the command / calculation the search starts with.
Item {
    id: root

    required property var cc

    // ">" and "=": one row describing what Enter does.
    StyledRect {
        visible: root.cc.mode !== "apps"
        width: parent.width
        height: 72
        radius: Tokens.rounding.large
        color: Colours.palette.m3secondaryContainer

        MaterialIcon {
            id: modeIcon

            anchors.left: parent.left
            anchors.leftMargin: Tokens.spacing.large
            anchors.verticalCenter: parent.verticalCenter
            text: root.cc.mode === "command" ? "terminal" : "calculate"
            fill: 1
            size: 28
            color: Colours.palette.m3onSecondaryContainer
        }

        Column {
            anchors.left: modeIcon.right
            anchors.leftMargin: Tokens.spacing.normal
            anchors.right: parent.right
            anchors.rightMargin: Tokens.spacing.large
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                width: parent.width
                text: root.cc.mode === "command" ? (root.cc.query.slice(1).trim() || "Type a command") : (Calc.result || "Type an expression")
                color: Colours.palette.m3onSecondaryContainer
                font.pixelSize: root.cc.mode === "calc" ? 22 : 15
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            StyledText {
                text: root.cc.mode === "command" ? "Enter runs it" : "Enter copies the result"
                color: Qt.alpha(Colours.palette.m3onSecondaryContainer, 0.8)
                font.pixelSize: 12
            }
        }
    }

    ListView {
        id: list

        visible: root.cc.mode === "apps"
        anchors.fill: parent
        clip: true
        spacing: 2
        model: root.cc.results
        currentIndex: root.cc.selected
        highlightMoveDuration: 0
        boundsBehavior: Flickable.StopAtBounds

        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

        StyledText {
            anchors.centerIn: parent
            visible: list.count === 0
            text: "No matching apps"
            color: Colours.palette.m3onSurfaceVariant
        }

        delegate: StyledRect {
            id: row

            required property var modelData
            required property int index
            readonly property bool current: index === root.cc.selected

            width: list.width
            height: 56
            radius: Tokens.rounding.normal
            color: current ? Colours.palette.m3secondaryContainer : hover.hovered ? Colours.palette.m3surfaceContainerHigh : "transparent"

            IconImage {
                id: appIcon

                anchors.left: parent.left
                anchors.leftMargin: Tokens.spacing.normal
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 36
                source: Quickshell.iconPath(row.modelData.icon, "application-x-executable")
            }

            Column {
                anchors.left: appIcon.right
                anchors.leftMargin: Tokens.spacing.normal
                anchors.right: parent.right
                anchors.rightMargin: Tokens.spacing.normal
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    width: parent.width
                    text: row.modelData.name
                    color: row.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width
                    visible: text !== ""
                    text: row.modelData.comment || row.modelData.genericName || ""
                    color: row.current ? Qt.alpha(Colours.palette.m3onSecondaryContainer, 0.8) : Colours.palette.m3onSurfaceVariant
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }

            HoverHandler {
                id: hover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: {
                    root.cc.selected = row.index;
                    root.cc.activate();
                }
            }
        }
    }
}
