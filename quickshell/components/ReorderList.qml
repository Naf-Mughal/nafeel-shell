pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// A list to put in order by dragging: each row has a grip at its start;
// drag it and the row lifts and follows, the others spring aside to make
// room, and a drop of goo shows where it'll land (GooIndicator); let go and
// it settles there. `moved(from, to)` says what changed (the model is the
// caller's to reorder). Rows are `delegate`s given `modelData` and `index`;
// all one height.
//   ReorderList { model: pins; rowHeight: 48; delegate: Component { ListRow { property var modelData; property int index; … } }
//                 onMoved: (a, b) => … }
Item {
    id: root

    property var model: []
    property Component delegate
    property real rowHeight: 48
    property real spacing: 2
    signal moved(int from, int to)

    readonly property real pitch: rowHeight + spacing
    property int dragFrom: -1
    property int dragTo: -1
    property real dragY: 0

    // Where row i sits while one is being dragged (the others make room).
    function slotOf(i: int): int {
        if (dragFrom < 0)
            return i;
        if (i === dragFrom)
            return dragTo;
        if (dragFrom < dragTo && i > dragFrom && i <= dragTo)
            return i - 1;
        if (dragFrom > dragTo && i >= dragTo && i < dragFrom)
            return i + 1;
        return i;
    }

    implicitWidth: 300
    implicitHeight: Math.max(0, model.length * pitch - spacing)

    // Where the dragged row will land.
    Item {
        id: landing

        y: root.dragTo * root.pitch
        width: root.width
        height: root.rowHeight
    }

    GooIndicator {
        anchors.fill: parent
        selected: root.dragFrom >= 0 ? landing : null
        fill: Colours.roleFill("secondary", "soft", 0)
        radius: Tokens.rounding.normal
    }

    Repeater {
        model: root.model

        Item {
            id: row

            required property var modelData
            required property int index
            readonly property bool dragged: root.dragFrom === index

            width: root.width
            height: root.rowHeight
            y: dragged ? root.dragY : root.slotOf(index) * root.pitch
            z: dragged ? 10 : 0
            scale: dragged ? 1.02 : 1

            Behavior on y {
                enabled: !row.dragged && !Tokens.reduceMotion
                SpringAnimation {
                    spring: Tokens.springK(4.5)
                    damping: Tokens.dampK(0.4)
                    epsilon: 0.3
                }
            }
            Behavior on scale {
                Anim {
                    duration: Tokens.anim.fast
                }
            }

            // Lifted: a hairline and the paper a step up, over the rest.
            StyledRect {
                anchors.fill: parent
                visible: row.dragged
                radius: Tokens.rounding.normal
                color: Colours.roleFill("paper", "soft", 4)
                border.width: Tokens.hairline
                border.color: Colours.palette.m3primary
            }

            Loader {
                anchors.fill: parent
                anchors.leftMargin: grip.width
                sourceComponent: root.delegate
                onLoaded: {
                    item.modelData = Qt.binding(() => row.modelData);
                    item.index = Qt.binding(() => row.index);
                }
            }

            // The grip: drag from here.
            Item {
                id: grip

                width: 28
                height: parent.height

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "drag_indicator"
                    size: 18
                    color: row.dragged || gripHover.hovered ? Colours.palette.m3onSurface : Colours.palette.m3outline
                }

                HoverHandler {
                    id: gripHover

                    cursorShape: row.dragged ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                }

                DragHandler {
                    id: drag

                    target: null
                    xAxis.enabled: false
                    property real startY: 0

                    onActiveChanged: {
                        if (active) {
                            startY = row.y;
                            root.dragY = row.y;
                            root.dragTo = row.index;
                            root.dragFrom = row.index;
                        } else if (root.dragFrom >= 0) {
                            const from = root.dragFrom, to = root.dragTo;
                            root.dragFrom = -1;
                            root.dragTo = -1;
                            if (from !== to)
                                root.moved(from, to);
                        }
                    }
                    onTranslationChanged: {
                        if (!active)
                            return;
                        root.dragY = Math.max(-root.rowHeight / 2, Math.min(root.height - root.rowHeight / 2, startY + translation.y));
                        root.dragTo = Math.max(0, Math.min(root.model.length - 1, Math.round(root.dragY / root.pitch)));
                    }
                }
            }
        }
    }
}
