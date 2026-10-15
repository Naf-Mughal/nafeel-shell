import QtQuick
import "modules/lock"
import "modules/lock/themes/xianxia"

// The login screen's session (desktop) picker, bottom left on the lock's
// paper: 道 and the session's name; a click opens the installed sessions
// above it, a click on one picks it (ctx.sessionIndex, what SDDM logs into).
Item {
    id: root

    property real sc: 1
    property real edge: 60
    property var ctx: null
    property bool open: false

    function nameAt(i) {
        let n = "";
        for (let k = 0; k < rows.count; k++)
            if (rows.itemAt(k)?.index === i)
                n = rows.itemAt(k).name;
        return n;
    }

    // The sessions, above the button.
    Paper {
        id: list

        x: root.edge
        anchors.bottom: button.top
        anchors.bottomMargin: 10 * root.sc
        width: 280 * root.sc
        height: col.implicitHeight + 12 * root.sc
        visible: opacity > 0.01
        opacity: root.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Xian.d(160)
            }
        }

        Column {
            id: col

            x: 6 * root.sc
            y: 6 * root.sc
            width: parent.width - 12 * root.sc

            Repeater {
                id: rows

                model: sessionModel

                Rectangle {
                    id: row

                    required property int index
                    required property string name
                    readonly property bool current: root.ctx && root.ctx.sessionIndex === index

                    width: col.width
                    height: 38 * root.sc
                    radius: Xian.radiusSmall
                    color: rowArea.containsMouse ? Xian.alpha(Xian.gold, 0.14) : current ? Xian.alpha(Xian.gold, 0.08) : "transparent"

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 12 * root.sc
                        text: row.name
                        font.family: Xian.serif
                        font.pixelSize: 15 * root.sc
                        color: row.current ? Xian.goldHi : Xian.paper
                    }

                    MouseArea {
                        id: rowArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.ctx.sessionIndex = row.index;
                            root.open = false;
                            root.ctx.poke();
                        }
                    }
                }
            }
        }
    }

    // The button: 道 and the session.
    Paper {
        id: button

        x: root.edge
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 44 * root.sc
        width: row.implicitWidth + 28 * root.sc
        height: 50 * root.sc
        radius: area.pressed ? Xian.radiusMorph : Xian.radiusNormal
        border.color: area.containsMouse || root.open ? Xian.alpha(Xian.gold, 0.5) : Xian.alpha(Xian.paper, 0.08)

        Row {
            id: row

            anchors.centerIn: parent
            spacing: 12 * root.sc

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "道"
                font.family: Xian.cjk
                font.weight: Font.Black
                font.pixelSize: 20 * root.sc
                color: Xian.gold
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    text: root.nameAt(root.ctx ? root.ctx.sessionIndex : 0) || "Session"
                    font.family: Xian.serif
                    font.pixelSize: 15 * root.sc
                    color: Xian.paper
                }

                Text {
                    text: "Session"
                    font.family: Xian.serif
                    font.italic: true
                    font.pixelSize: 11 * root.sc
                    color: Xian.paperDim
                }
            }
        }

        MouseArea {
            id: area

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.open = !root.open;
                root.ctx.poke();
            }
        }
    }
}
