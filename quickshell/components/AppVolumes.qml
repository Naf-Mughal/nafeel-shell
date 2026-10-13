pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// A volume slider per app playing sound: the app's icon (click to mute),
// its name and level, and the slider. Nothing while no app plays.
Column {
    id: root

    spacing: Tokens.spacing.small
    visible: Audio.streams.length > 0

    SectionLabel {
        text: "Apps"
    }

    Repeater {
        model: Audio.streams

        Row {
            id: app

            required property var modelData
            readonly property bool muted: !!modelData.audio?.muted
            readonly property real level: modelData.audio?.volume ?? 0

            width: root.width
            spacing: Tokens.spacing.small

            Item {
                width: 40
                height: 40
                anchors.verticalCenter: parent.verticalCenter

                AppIcon {
                    anchors.centerIn: parent
                    appId: Audio.streamAppId(app.modelData)
                    size: 26
                    opacity: app.muted ? 0.35 : 1
                }

                MaterialIcon {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    visible: app.muted
                    text: "volume_off"
                    size: 14
                    color: Colours.palette.m3error
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Audio.toggleStreamMute(app.modelData)
                }
            }

            Column {
                width: parent.width - 40 - Tokens.spacing.small
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Item {
                    width: parent.width
                    height: name.implicitHeight

                    StyledText {
                        id: name

                        width: parent.width - pct.implicitWidth - Tokens.spacing.small
                        text: Audio.streamName(app.modelData)
                        color: Colours.palette.m3onSurfaceVariant
                        font.pixelSize: Tokens.font.small
                        elide: Text.ElideRight
                    }

                    MicroLabel {
                        id: pct

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: app.muted ? "muted" : `${Math.round(app.level * 100)}`
                    }
                }

                StyledSlider {
                    width: parent.width
                    implicitHeight: 20
                    value: app.level
                    to: 1.5
                    fill: app.muted ? Colours.palette.m3outline : Colours.palette.m3secondary
                    ink: Colours.palette.m3onSecondary
                    track: Colours.palette.m3secondaryContainer
                    onMoved: v => Audio.setStreamVolume(app.modelData, v)
                }
            }
        }
    }
}
