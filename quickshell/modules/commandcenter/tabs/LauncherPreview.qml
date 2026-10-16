pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import Nafeel
import qs.config
import qs.services
import qs.components

// The launcher's preview of the selected result (services/Preview.qml): a
// file's text with the matching line marked, a picture, a directory's
// entries, a document's first page, a clipboard entry, an emoji large, an
// app's details, a window live.
Surface {
    id: root

    readonly property var spec: Preview.spec
    readonly property var file: Preview.data
    readonly property bool fileKind: spec?.kind === "file"
    // Lines of text to show (a file's, or the clipboard's).
    readonly property var lines: fileKind ? (file?.kind === "text" || file?.kind === "dir" ? (file.text ?? "").split("\n") : []) : spec?.kind === "text" ? (spec.text ?? "").split("\n") : []
    readonly property int first: fileKind ? file?.first ?? 1 : 1
    readonly property int mark: fileKind ? file?.mark ?? 0 : 0
    readonly property string imagePath: spec?.kind === "image" ? spec.path ?? "" : fileKind && file?.kind === "image" ? spec.path : ""
    readonly property string title: spec?.title ?? (fileKind ? spec.path.slice(spec.path.lastIndexOf("/") + 1) : "")
    readonly property var meta: fileKind ? file?.meta ?? [] : []

    role: "paper"
    level: 2
    shape: "large"
    clip: true

    // A glyph (an emoji) large, with its name and codes.
    Column {
        anchors.centerIn: parent
        width: parent.width - Tokens.spacing.large * 2
        visible: root.spec?.kind === "glyph"
        spacing: Tokens.spacing.normal

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.spec?.glyph ?? ""
            font.pixelSize: 96
        }

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.spec?.title ?? ""
            wrapMode: Text.WordWrap
            font.pixelSize: Tokens.font.row
            font.weight: Font.DemiBold
        }

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: (root.spec?.lines ?? []).join("\n")
            wrapMode: Text.WordWrap
            color: Colours.palette.m3onSurfaceVariant
            font.pixelSize: Tokens.font.small
        }
    }

    // Prose (an answer): what was asked, then the text, wrapped.
    Item {
        anchors.fill: parent
        anchors.margins: Tokens.spacing.large
        visible: root.spec?.kind === "prose"
        clip: true

        Column {
            width: parent.width
            spacing: Tokens.spacing.normal

            StyledText {
                width: parent.width
                text: root.spec?.title ?? ""
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                color: Colours.palette.m3onSurfaceVariant
                font.pixelSize: Tokens.font.small
            }

            StyledText {
                width: parent.width
                text: root.spec?.text ?? ""
                wrapMode: Text.Wrap
                font.pixelSize: Tokens.font.row
            }
        }
    }

    // An app, a window, anything described: an icon or live picture on top,
    // the name and the lines under it.
    Item {
        anchors.fill: parent
        anchors.margins: Tokens.spacing.large
        visible: root.spec?.kind === "app" || root.spec?.kind === "window" || root.spec?.kind === "info"

        Item {
            id: head

            width: parent.width
            height: root.spec?.kind === "window" ? Math.round(width * 0.62) : 72

            WindowThumb {
                anchors.fill: parent
                visible: root.spec?.kind === "window"
                windowId: root.spec?.kind === "window" ? root.spec.id : ""
                crop: true
                fps: 10
            }

            IconImage {
                anchors.centerIn: parent
                visible: root.spec?.kind === "app"
                implicitSize: 64
                source: root.spec?.kind === "app" && root.spec.icon ? Quickshell.iconPath(root.spec.icon, "application-x-executable") : ""
            }

            MaterialIcon {
                anchors.centerIn: parent
                visible: root.spec?.kind === "info"
                text: root.spec?.icon ?? "info"
                size: 48
                color: Colours.palette.m3onSurfaceVariant
            }
        }

        Column {
            anchors.top: head.bottom
            anchors.topMargin: Tokens.spacing.normal
            width: parent.width
            spacing: Tokens.spacing.small

            StyledText {
                width: parent.width
                text: root.spec?.title ?? root.spec?.name ?? ""
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                font.pixelSize: Tokens.font.row
                font.weight: Font.DemiBold
            }

            Repeater {
                model: root.spec?.lines ?? []

                StyledText {
                    required property string modelData

                    width: parent.width
                    text: modelData
                    wrapMode: Text.Wrap
                    maximumLineCount: 6
                    elide: Text.ElideRight
                    color: Colours.palette.m3onSurfaceVariant
                    font.pixelSize: Tokens.font.small
                }
            }
        }
    }

    // A file, the clipboard, a picture: the name and its facts on top, the
    // content under them.
    Item {
        anchors.fill: parent
        anchors.margins: Tokens.spacing.normal
        visible: root.fileKind || root.spec?.kind === "text" || root.spec?.kind === "image"

        Column {
            id: top

            width: parent.width
            visible: root.fileKind

            StyledText {
                width: parent.width
                text: root.title
                elide: Text.ElideMiddle
                font.pixelSize: Tokens.font.row
                font.weight: Font.DemiBold
            }

            StyledText {
                width: parent.width
                text: root.meta.join("   ·   ")
                elide: Text.ElideRight
                color: Colours.palette.m3onSurfaceVariant
                font.pixelSize: Tokens.font.micro
            }
        }

        Item {
            anchors.top: top.visible ? top.bottom : parent.top
            anchors.topMargin: top.visible ? Tokens.spacing.small : 0
            anchors.bottom: parent.bottom
            width: parent.width
            clip: true

            Image {
                anchors.fill: parent
                visible: root.imagePath !== ""
                source: root.imagePath ? Wallpapers.still(root.imagePath, false) : ""
                sourceSize: Qt.size(width * 2, height * 2)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
            }

            // Lines, the matching one marked (and its number).
            Column {
                width: parent.width
                visible: root.imagePath === "" && root.lines.length > 0
                opacity: Preview.loading ? 0.5 : 1

                Repeater {
                    model: root.lines

                    delegate: Rectangle {
                        required property string modelData
                        required property int index

                        width: parent.width
                        height: Math.max(line.implicitHeight, 15)
                        radius: 3
                        color: root.mark === index + 1 ? Qt.alpha(Colours.palette.m3primary, 0.22) : "transparent"

                        StyledText {
                            id: line

                            width: parent.width
                            text: modelData
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            font.family: Tokens.font.mono
                            font.pixelSize: 11
                            color: root.mark === index + 1 ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                        }
                    }
                }
            }

            StyledText {
                anchors.centerIn: parent
                visible: root.fileKind && root.imagePath === "" && root.lines.length === 0 && !Preview.loading
                text: "No preview"
                color: Colours.palette.m3outline
                font.pixelSize: Tokens.font.small
            }
        }
    }
}
