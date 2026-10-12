import QtQuick
import qs.config
import qs.services
import qs.components

// Now: the icon, the temperature, what it's like and where.
Surface {
    id: root

    level: 2
    implicitHeight: 96

    // Kept inside the card: the words take what the icon leaves and elide;
    // the place goes on its own line so a long one doesn't push the rest out.
    Row {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Tokens.spacing.large
        anchors.rightMargin: Tokens.spacing.large
        spacing: Tokens.spacing.large

        MaterialIcon {
            id: icon

            anchors.verticalCenter: parent.verticalCenter
            text: Weather.icon
            size: 44
            color: Colours.roleInk("primary", "ghost")
            fill: 1
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: row.width - icon.width - row.spacing

            StyledText {
                width: parent.width
                text: Weather.current ? Time.deg(Weather.temp) : "—"
                color: root.ink
                font.family: Tokens.font.serif
                font.pixelSize: 32
                elide: Text.ElideRight
            }

            MicroLabel {
                width: parent.width
                text: Weather.current ? Weather.description : "no weather yet"
                elide: Text.ElideRight
            }

            MicroLabel {
                width: parent.width
                visible: Weather.current !== null && Weather.place !== ""
                text: Weather.place
                elide: Text.ElideRight
            }
        }
    }
}
