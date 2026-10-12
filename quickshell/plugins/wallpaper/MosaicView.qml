import QtQuick
import qs.config
import qs.services
import qs.components

// The mosaic: the library as a grid of 16:9 tiles, scrolled by rows (after
// Ryoku's mosaic view, without its slanted cells). Arrows move in two
// dimensions; the wheel scrolls.
GridView {
    id: root

    signal picked(int index, bool close)

    readonly property int columns: Math.max(3, Math.floor(width / 230))

    function move(dx: int, dy: int): void {
        if (count === 0)
            return;
        currentIndex = Math.max(0, Math.min(count - 1, currentIndex + dx + dy * columns));
    }

    function centreOn(i: int): void {
        if (i < 0 || i >= count)
            return;
        currentIndex = i;
        positionViewAtIndex(i, GridView.Center);
    }

    clip: true
    cellWidth: Math.floor(width / columns)
    cellHeight: Math.round(cellWidth * 9 / 16)
    cacheBuffer: 400
    boundsBehavior: Flickable.StopAtBounds
    highlightFollowsCurrentItem: false
    keyNavigationEnabled: false
    onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)

    delegate: WallCard {
        required property var modelData
        required property int index

        wall: modelData
        width: root.cellWidth
        height: root.cellHeight
        details: true
        selected: GridView.isCurrentItem
        onTapped: {
            root.currentIndex = index;
            root.picked(index, false);
        }
        onDoubleTapped: {
            root.currentIndex = index;
            root.picked(index, true);
        }
    }
}
