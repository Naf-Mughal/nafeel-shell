import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// The time stacked large (hours over minutes), the day under it.
Surface {
    id: root

    level: 2
    implicitWidth: 112

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Column {
        anchors.centerIn: parent
        spacing: -6

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Time.hours(clock.date)
            color: Colours.roleInk("primary", "ghost")
            font.family: Tokens.font.serif
            font.pixelSize: 46
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "mm")
            color: root.ink
            font.family: Tokens.font.serif
            font.pixelSize: 46
        }

        Item {
            width: 1
            height: 12
        }

        MicroLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "ddd d MMM")
        }
    }
}
