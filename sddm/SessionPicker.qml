import QtQuick
import "modules/lock"
import "modules/lock/themes/xianxia"

// The login screen's session (desktop) picker, bottom left: a carousel on
// one card, made like the cultivator's (the paper, the cover's ink fade, a
// seal with the session's initial, its name large). Scroll, swipe up or
// down, or click to flip; the card in front is what SDDM logs into
// (ctx.sessionIndex); dots on the right say where you are.
Item {
    id: root

    property real sc: 1
    property real edge: 60
    property var ctx: null

    readonly property int count: names.count
    readonly property int index: ctx ? ctx.sessionIndex : 0
    // Which way the last flip went (the new card comes from there).
    property int dir: 1

    function nameAt(i) {
        // (count: read again as the names arrive.)
        const item = names.count > 0 ? names.itemAt(i) : null;
        return item ? item.name : "";
    }

    function flip(step) {
        if (!ctx || count < 2)
            return;
        dir = step;
        ctx.sessionIndex = (index + step + count) % count;
        ctx.poke();
    }

    // The sessions' names (not drawn).
    Repeater {
        id: names

        model: sessionModel

        Item {
            required property string name
        }
    }

    Item {
        id: card

        x: root.edge
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 44 * root.sc
        width: 300 * root.sc
        height: 100 * root.sc

        Paper {
            anchors.fill: parent
            border.color: area.containsMouse ? Xian.alpha(Xian.gold, 0.4) : Xian.alpha(Xian.paper, 0.08)

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: parent.radius
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Xian.alpha(Xian.ink, 0.55) }
                    GradientStop { position: 1; color: Xian.alpha(Xian.ink, 0.1) }
                }
            }
        }

        // The front card, swapped with a short rise (or fall) and a fade.
        Item {
            id: front

            property real t: 1

            anchors.fill: parent
            clip: true

            Row {
                x: 18 * root.sc
                y: (parent.height - height) / 2 + (1 - front.t) * 16 * root.sc * root.dir
                opacity: front.t
                spacing: 16 * root.sc

                // The session's initial, a seal as the cultivator's face.
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 62 * root.sc
                    height: width

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Xian.alpha(Xian.ink, 0.6)
                        border.width: 1
                        border.color: Xian.alpha(Xian.gold, 0.55)
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4 * root.sc
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: Xian.alpha(Xian.gold, 0.25)
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.nameAt(root.index).charAt(0).toUpperCase()
                        font.family: Xian.serif
                        font.pixelSize: 28 * root.sc
                        color: Xian.goldHi
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3 * root.sc

                    Row {
                        spacing: 8 * root.sc

                        Text {
                            id: sessionName

                            width: Math.min(implicitWidth, 150 * root.sc)
                            elide: Text.ElideRight
                            text: root.nameAt(root.index) || "Session"
                            font.family: Xian.serif
                            font.pixelSize: 21 * root.sc
                            color: Xian.paper
                        }

                        Text {
                            anchors.baseline: sessionName.baseline
                            text: "道"
                            font.family: Xian.cjk
                            font.pixelSize: 13 * root.sc
                            color: Xian.gold
                        }
                    }

                    Text {
                        text: ("Session · " + (root.index + 1) + " / " + Math.max(1, root.count)).toUpperCase()
                        font.family: Xian.serif
                        font.pixelSize: 10 * root.sc
                        font.letterSpacing: 1.5 * root.sc
                        color: Xian.paperDim
                    }
                }
            }

            NumberAnimation {
                id: arrive

                target: front
                property: "t"
                from: 0
                to: 1
                duration: Xian.d(320)
                easing.type: Easing.OutCubic
            }
        }

        // Where you are.
        Column {
            anchors.right: parent.right
            anchors.rightMargin: 14 * root.sc
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4 * root.sc
            visible: root.count > 1

            Repeater {
                model: root.count

                Rectangle {
                    required property int index

                    width: 5 * root.sc
                    height: index === root.index ? 14 * root.sc : 5 * root.sc
                    radius: width / 2
                    color: index === root.index ? Xian.gold : Xian.alpha(Xian.paper, 0.3)

                    Behavior on height {
                        NumberAnimation {
                            duration: Xian.d(160)
                        }
                    }
                }
            }
        }

        MouseArea {
            id: area

            property real pressY: 0

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: e => pressY = e.y
            onReleased: e => {
                const dy = e.y - pressY;
                root.flip(Math.abs(dy) > 24 ? (dy < 0 ? 1 : -1) : 1);
            }
            onWheel: e => {
                if (Math.abs(e.angleDelta.y) >= 60)
                    root.flip(e.angleDelta.y > 0 ? -1 : 1);
            }
        }
    }

    onIndexChanged: if (Xian.motion > 0)
        arrive.restart()
}
