import QtQuick
import qs.config
import qs.services
import qs.components

// The OSD's content, a pill out of the top bar: for a level (volume,
// microphone, brightness) the panels' M3 slider with the percentage on its icon
// button, or an icon and a label for a toggle.
Item {
    id: root

    // The OSD's state (the plugin's root).
    readonly property var osd: Plugins.instance("osd")

    readonly property bool level: root.osd?.kind !== "toggle"
    property int pad: Tokens.spacing.large
    // Narrower inside a panel's heading (Panel.hostsOsd).
    property int sliderWidth: 260
    property int buttonSize: 40
    // The label's room, past which it elides.
    property int labelWidth: 520

    implicitWidth: level ? buttonSize + Tokens.spacing.small + sliderWidth + pad * 2 : toggleRow.implicitWidth + pad * 2
    implicitHeight: 56

    // A level: the M3 slider (as in the panels), its icon button carrying the
    // percentage; drag it to change the level right there.
    Row {
        visible: root.level
        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            size: root.buttonSize
            icon: root.osd?.icon
            filled: true
            fillColour: root.osd?.kind === "mic" ? Colours.palette.m3tertiaryContainer : Colours.palette.m3secondaryContainer
            inkColour: root.osd?.kind === "mic" ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSecondaryContainer
            caption: Math.round(root.osd?.value * 100)
            onClicked: {
                if (root.osd?.kind === "volume")
                    Audio.toggleMute();
            }
        }

        StyledSlider {
            anchors.verticalCenter: parent.verticalCenter
            width: root.sliderWidth
            value: root.osd?.value
            to: root.osd?.kind === "brightness" ? 1 : Math.max(1, root.osd?.value)
            fill: root.osd?.value > 1 ? Colours.palette.m3error : root.osd?.kind === "mic" ? Colours.palette.m3tertiary : Colours.palette.m3primary
            ink: root.osd?.kind === "mic" ? Colours.palette.m3onTertiary : Colours.palette.m3onPrimary
            track: root.osd?.kind === "mic" ? Colours.palette.m3tertiaryContainer : Colours.palette.m3secondaryContainer
            onMoved: v => {
                if (root.osd?.kind === "brightness")
                    Brightness.set(v);
                else if (root.osd?.kind === "volume")
                    Audio.setVolume(v);
            }
        }
    }

    Row {
        id: toggleRow

        visible: !root.level
        anchors.centerIn: parent
        spacing: Tokens.spacing.normal

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: root.osd?.icon
            fill: 1
            size: 22
            color: Colours.palette.m3primary
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.labelWidth)
            text: root.osd?.label
            elide: Text.ElideRight
            font.pixelSize: Tokens.font.row
            font.weight: Font.DemiBold
        }
    }
}
