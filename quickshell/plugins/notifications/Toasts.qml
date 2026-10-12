pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// The toast stack, newest on top (at most four). Each toast glides in from
// the right edge and leaves the same way, and the others slide to close the
// gap (Ryoku's notification glide). Hovering pauses their countdown.
ListView {
    id: root

    readonly property int maxShown: Notifs.maxShown

    // The model mirrors Notifs.popups by key, so arrivals, departures and
    // reorders become ListView transitions instead of a rebuilt list.
    function sync(): void {
        const want = Notifs.popups.slice(0, maxShown).map(n => n.key);
        for (let i = toastModel.count - 1; i >= 0; i--)
            if (!want.includes(toastModel.get(i).key))
                toastModel.remove(i);
        want.forEach((key, at) => {
            let found = -1;
            for (let i = 0; i < toastModel.count; i++)
                if (toastModel.get(i).key === key)
                    found = i;
            if (found < 0)
                toastModel.insert(at, {
                    key: key
                });
            else if (found !== at)
                toastModel.move(found, at, 1);
        });
    }

    implicitHeight: contentHeight
    interactive: false
    spacing: Tokens.spacing.small
    model: ListModel {
        id: toastModel
    }

    Component.onCompleted: sync()

    Connections {
        target: Notifs

        function onPopupsChanged(): void {
            root.sync();
        }
    }

    HoverHandler {
        onHoveredChanged: Notifs.hoveringPopups = hovered
    }

    delegate: NotificationCard {
        id: card

        required property int key
        // The last known entry, so a leaving toast still has something to show.
        property var last: ({
                app: "",
                summary: "",
                body: "",
                image: "",
                icon: "",
                time: 0,
                urgency: 1,
                actions: []
            })

        width: root.width
        toast: true
        entry: {
            const found = Notifs.history.find(n => n.key === key);
            if (found)
                card.last = found;
            return found ?? card.last;
        }
    }

    add: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "x"
                from: root.width
                to: 0
                duration: Tokens.anim.slow
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.anim.expressiveSpatial
            }
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Tokens.anim.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.anim.emphasizedDecel
            }
        }
    }

    remove: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "x"
                to: root.width
                duration: Tokens.anim.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.anim.emphasizedAccel
            }
            NumberAnimation {
                property: "opacity"
                to: 0
                duration: Tokens.anim.fast
            }
        }
    }

    displaced: Transition {
        NumberAnimation {
            properties: "x,y"
            duration: Tokens.anim.slow
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.anim.expressiveSpatial
        }
    }
}
