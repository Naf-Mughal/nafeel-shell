import QtQuick
import qs.config

// A scrolling row (or column) of things: chips, cards, wallpapers, windows.
// The wheel scrolls it either way (WheelScroll), it clips to itself, and with `centred`
// the current item is kept in the middle (a carousel).
ListView {
    id: root

    property bool centred: false
    // `wheelScrolls: false` leaves the wheel to the owner (a carousel that
    // steps its selection instead).
    property bool wheelScrolls: true

    orientation: ListView.Horizontal
    spacing: Tokens.spacing.normal
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    highlightFollowsCurrentItem: centred
    highlightMoveDuration: Tokens.anim.normal
    highlightRangeMode: centred ? ListView.ApplyRange : ListView.NoHighlightRange
    preferredHighlightBegin: centred ? (orientation === ListView.Horizontal ? width : height) / 2 - (currentItem ? (orientation === ListView.Horizontal ? currentItem.width : currentItem.height) / 2 : 0) : 0
    preferredHighlightEnd: centred ? (orientation === ListView.Horizontal ? width : height) / 2 + (currentItem ? (orientation === ListView.Horizontal ? currentItem.width : currentItem.height) / 2 : 0) : 0

    WheelScroll {
        enabled: root.wheelScrolls
        view: root
        horizontal: root.orientation === ListView.Horizontal
    }
}
