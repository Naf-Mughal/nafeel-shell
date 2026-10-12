import QtQuick
import qs.config
import qs.services
import qs.components

// The strip: one row of wide cards, the selection kept in the middle.
//
// Picker views share one contract: `model` (the walls shown), `currentIndex`,
// move(dx, dy) for the keys, centreOn(i), and picked(index, close).
Strip {
    id: root

    signal picked(int index, bool close)

    function move(dx: int, dy: int): void {
        const by = dx + dy;
        if (count > 0)
            currentIndex = Math.max(0, Math.min(count - 1, currentIndex + by));
    }

    function centreOn(i: int): void {
        if (i < 0 || i >= count)
            return;
        currentIndex = i;
        positionViewAtIndex(i, ListView.Center);
    }

    cacheBuffer: 600
    centred: true

    delegate: WallCard {
        required property var modelData
        required property int index

        wall: modelData
        width: Math.round(root.height * 16 / 9)
        height: root.height
        selected: ListView.isCurrentItem
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
