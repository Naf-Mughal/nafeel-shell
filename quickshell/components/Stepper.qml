import QtQuick
import qs.config
import qs.services
import "keynav.js" as KeyNav

// − value +: a number stepped by `step` between `from` and `to`, the value
// rolling as it changes (RollText). Hold a button to keep stepping; Left /
// Right (or −/+) from the keyboard.
//   Stepper { value: 5; from: 1; to: 30; unit: " min"; onMoved: v => … }
Item {
    id: root

    property real value
    property real from: 0
    property real to: 100
    property real step: 1
    property string unit: ""
    property int decimals: 0
    signal moved(real value)

    function nudge(dir: int): void {
        const v = Math.max(from, Math.min(to, value + dir * step));
        if (v !== value)
            moved(v);
    }

    implicitWidth: minus.width + readout.width + plus.width + Tokens.spacing.small * 2
    implicitHeight: 36

    property bool focusByKey: false
    activeFocusOnTab: true
    onActiveFocusChanged: {
        if (!activeFocus)
            focusByKey = false;
    }
    Keys.onPressed: event => {
        const k = event.key;
        if (k === Qt.Key_Left || k === Qt.Key_Minus)
            nudge(-1);
        else if (k === Qt.Key_Right || k === Qt.Key_Plus || k === Qt.Key_Equal)
            nudge(1);
        else if (k === Qt.Key_Down || k === Qt.Key_Tab)
            KeyNav.move(root, true);
        else if (k === Qt.Key_Up || k === Qt.Key_Backtab)
            KeyNav.move(root, false);
        else
            return;
        event.accepted = true;
    }

    // Held: keeps stepping, quicker after a moment.
    Timer {
        id: repeat

        property int dir: 0
        property int ticks: 0

        interval: ticks < 4 ? 260 : 80
        repeat: true
        onTriggered: {
            ticks++;
            root.nudge(dir);
        }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spacing.small

        IconButton {
            id: minus

            icon: "remove"
            size: 36
            opacity: root.value > root.from ? 1 : 0.4
            onClicked: root.nudge(-1)
            onPressedChanged: {
                if (pressed) {
                    repeat.dir = -1;
                    repeat.ticks = 0;
                    repeat.start();
                } else {
                    repeat.stop();
                }
            }
        }

        StyledRect {
            id: readout

            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(56, roll.implicitWidth + Tokens.spacing.large)
            height: 36
            radius: Tokens.rounding.small
            color: Colours.palette.m3surfaceContainerHighest
            border.width: root.activeFocus && root.focusByKey ? 2 : 0
            border.color: Colours.palette.m3primary

            RollText {
                id: roll

                anchors.centerIn: parent
                text: root.value.toFixed(root.decimals) + root.unit
                font.pixelSize: Tokens.font.row
                font.weight: Font.DemiBold
            }
        }

        IconButton {
            id: plus

            icon: "add"
            size: 36
            opacity: root.value < root.to ? 1 : 0.4
            onClicked: root.nudge(1)
            onPressedChanged: {
                if (pressed) {
                    repeat.dir = 1;
                    repeat.ticks = 0;
                    repeat.start();
                } else {
                    repeat.stop();
                }
            }
        }
    }
}
