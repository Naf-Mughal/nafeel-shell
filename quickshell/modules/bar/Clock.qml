import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// The bar's clock: hours and minutes in the serif, AM/PM as a tracked
// micro-label, and the double-hour (时辰) branch, in the CJK serif. Stacked
// down a vertical bar; on one line across a horizontal one.
Item {
    id: root

    property color ink: Colours.palette.m3onSurface
    property bool horizontal: false

    implicitWidth: horizontal ? line.implicitWidth : Tokens.barWidth
    implicitHeight: horizontal ? line.implicitHeight : stack.implicitHeight

    Row {
        id: line

        anchors.centerIn: parent
        visible: root.horizontal
        spacing: Tokens.spacing.small

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: `${Time.hours(clock.date)}:${Qt.formatTime(clock.date, "mm")}`
            color: root.ink
            font.family: Tokens.font.serif
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }

        MicroLabel {
            anchors.verticalCenter: parent.verticalCenter
            visible: text !== ""
            text: Time.meridiem(clock.date)
            color: Colours.palette.m3onSurfaceVariant
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: Xian.shichen(clock.date).zh.charAt(0)
            color: Colours.palette.m3primary
            font.family: Tokens.font.cjk
            font.pixelSize: 11
            font.weight: Font.Bold
        }
    }

    Column {
        id: stack

        anchors.horizontalCenter: parent.horizontalCenter
        visible: !root.horizontal
        spacing: 0

        SystemClock {
            id: clock

            precision: SystemClock.Minutes
        }

        StyledText {
            width: Tokens.barWidth
            horizontalAlignment: Text.AlignHCenter
            text: Time.hours(clock.date)
            color: root.ink
            font.family: Tokens.font.serif
            font.pixelSize: 17
            font.weight: Font.DemiBold
        }

        StyledText {
            width: Tokens.barWidth
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatTime(clock.date, "mm")
            color: root.ink
            font.family: Tokens.font.serif
            font.pixelSize: 17
            font.weight: Font.DemiBold
        }

        MicroLabel {
            width: Tokens.barWidth
            horizontalAlignment: Text.AlignHCenter
            topPadding: 2
            visible: text !== ""
            text: Time.meridiem(clock.date)
            // Tracking pads the right side only; nudge it back onto the axis.
            leftPadding: font.letterSpacing
            color: Colours.palette.m3onSurfaceVariant
        }

        Hairline {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 14
        }

        StyledText {
            width: Tokens.barWidth
            horizontalAlignment: Text.AlignHCenter
            topPadding: 4
            text: Xian.shichen(clock.date).zh.charAt(0)
            color: Colours.palette.m3primary
            font.family: Tokens.font.cjk
            font.pixelSize: 15
            font.weight: Font.Bold
        }
    }
}
