import QtQuick
import qs.config
import qs.services

// A volume slider with a mute chip in front.
Row {
    id: row

    property string icon
    property bool muted
    property real value
    property bool tertiary

    signal toggleMute
    signal moved(real value)

    spacing: Tokens.spacing.small

    IconButton {
        icon: row.icon
        filled: !row.muted
        fillColour: row.tertiary ? Colours.palette.m3tertiaryContainer : Colours.palette.m3secondaryContainer
        inkColour: row.tertiary ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSecondaryContainer
        caption: Math.round(row.value * 100)
        onClicked: row.toggleMute()
    }

    StyledSlider {
        width: parent.width - 40 - Tokens.spacing.small
        value: row.value
        to: 1.5
        fill: row.muted ? Colours.palette.m3outline : row.tertiary ? Colours.palette.m3tertiary : Colours.palette.m3primary
        ink: row.tertiary ? Colours.palette.m3onTertiary : Colours.palette.m3onPrimary
        track: row.tertiary ? Colours.palette.m3tertiaryContainer : Colours.palette.m3secondaryContainer
        onMoved: v => row.moved(v)
    }
}
