import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// The bar's clock, in its vertical middle: hours and minutes in the serif,
// AM/PM as a tracked micro-label, and the double-hour (时辰) branch beneath,
// in the CJK serif.
Column {
    id: root

    property color ink: Colours.palette.m3onSurface

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
