import QtQuick
import qs.config
import qs.services
import "hosts.js" as Hosts

// Something that floats over its panel (Menu, a Select's list, Dialog): put
// in the panel's body above everything (hosts.js), placed by `from` (below
// it, or above where there's no room), kept inside the panel, and unfolded
// like ink from the point it opened from: a window growing from there to the
// full size, the content still inside it (not stretched). A press outside
// closes it (and goes no further). Esc closes it.
Item {
    id: root

    // What it opens from (its rect, in the host, places it); or `at`, a
    // point in `from` (a right-click).
    property Item from: parent
    property point at: Qt.point(-1, -1)
    property bool open: false
    // "below" | "above" | "centre" (a dialog).
    property string placement: "below"
    property real gap: 4
    // A dim over the panel while it's open (a dialog).
    property bool scrim: false
    default property alias content: card.data
    property alias card: card
    readonly property real unfold: _p

    signal closed
    // Keys while it's open (Esc already closes it).
    signal keyPressed(var event)

    function show(): void {
        open = true;
    }
    function hide(): void {
        open = false;
    }

    onOpenChanged: {
        if (open) {
            host = Hosts.of(from);
            place();
            card.forceActiveFocus();
        } else {
            closed();
        }
    }

    property Item host: null
    property real _p: open ? 1 : 0
    Behavior on _p {
        enabled: !Tokens.reduceMotion
        Anim {
            duration: root.open ? Tokens.anim.normal : Tokens.anim.fast
            easing.bezierCurve: root.open ? Tokens.anim.emphasizedDecel : Tokens.anim.emphasizedAccel
        }
    }

    // Where the card goes and the point it unfolds from, in the host.
    property rect target
    property point origin

    function place(): void {
        if (!host || !from)
            return;
        const w = card.implicitWidth, h = card.implicitHeight, m = 8;
        const a = from.mapToItem(host, 0, 0, from.width, from.height);
        let x, y;
        if (placement === "centre") {
            x = (host.width - w) / 2;
            y = (host.height - h) / 2;
            origin = Qt.point(host.width / 2, host.height / 2);
        } else {
            const pt = at.x >= 0 ? from.mapToItem(host, at.x, at.y) : null;
            x = pt ? pt.x : a.x;
            const below = pt ? pt.y : a.y + a.height + gap;
            const above = (pt ? pt.y : a.y - gap) - h;
            y = placement === "above" ? (above >= m ? above : below) : (below + h <= host.height - m ? below : above);
            origin = pt ?? Qt.point(a.x + Math.min(a.width, w) / 2, y >= a.y ? a.y + a.height : a.y);
        }
        target = Qt.rect(Math.max(m, Math.min(host.width - w - m, x)), Math.max(m, Math.min(host.height - h - m, y)), w, h);
    }

    Item {
        id: layer

        parent: root.host
        anchors.fill: parent
        z: 1000
        visible: root._p > 0.001

        // Outside: a press closes it and goes no further.
        MouseArea {
            anchors.fill: parent
            enabled: root.open
            acceptedButtons: Qt.AllButtons
            onPressed: root.open = false
        }

        Rectangle {
            visible: root.scrim
            anchors.fill: parent
            color: Qt.alpha(Colours.palette.m3scrim, 0.4)
            opacity: root._p
        }

        // The window it unfolds through: from the origin to the full card.
        Item {
            id: reveal

            readonly property real p: root._p
            x: root.origin.x + (root.target.x - root.origin.x) * p
            y: root.origin.y + (root.target.y - root.origin.y) * p
            width: root.target.width * p
            height: root.target.height * p
            clip: p < 1
            opacity: Math.min(1, p * 2)

            Surface {
                id: card

                x: root.target.x - reveal.x
                y: root.target.y - reveal.y
                width: implicitWidth
                height: implicitHeight
                level: 4
                outlined: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        root.open = false;
                        event.accepted = true;
                    } else {
                        root.keyPressed(event);
                    }
                }

                // Presses inside stay inside.
                MouseArea {
                    anchors.fill: parent
                    z: -1
                    acceptedButtons: Qt.AllButtons
                }
            }
        }
    }
}
