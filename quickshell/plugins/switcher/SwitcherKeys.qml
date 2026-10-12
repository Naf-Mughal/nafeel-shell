import QtQuick
import Nafeel
import qs.services

// The switcher's keyboard, apart from its carousel so it works before the
// carousel shows (a quick tap never shows it). Takes the focus while the
// switcher is open on this frame.
//
// Tab / Shift+Tab or the arrows move, Enter focuses, Esc cancels; while opened
// by Alt+Tab, letting go of Alt focuses the selection.
Item {
    id: root

    // The frame's screen (set by the frame for its overlays); the switcher is
    // open here when it's open on this screen.
    property var shellScreen: null
    readonly property bool here: ShellState.isOpen("switcher", shellScreen?.name ?? "")

    function grab(): void {
        if (Switcher.open && root.here)
            root.forceActiveFocus();
    }

    // After the frame's own Esc catcher takes the focus on a new pin.
    Connections {
        target: Switcher

        function onOpenChanged(): void {
            Qt.callLater(root.grab);
        }
    }

    onHereChanged: Qt.callLater(grab)

    Keys.onPressed: event => {
        if (!Switcher.open)
            return;
        const back = (event.modifiers & Qt.ShiftModifier) !== 0;
        switch (event.key) {
        case Qt.Key_Tab:
            Switcher.move(back ? -1 : 1);
            break;
        case Qt.Key_Backtab:
        case Qt.Key_Left:
        case Qt.Key_Up:
            Switcher.move(-1);
            break;
        case Qt.Key_Right:
        case Qt.Key_Down:
            Switcher.move(1);
            break;
        case Qt.Key_Home:
            Switcher.select(0);
            break;
        case Qt.Key_End:
            Switcher.select(Switcher.list.length - 1);
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            Switcher.commit();
            break;
        case Qt.Key_Escape:
            Switcher.cancel();
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    Keys.onReleased: event => {
        if (Switcher.holding && (event.key === Qt.Key_Alt || event.key === Qt.Key_AltGr || event.key === Qt.Key_Meta)) {
            event.accepted = true;
            Switcher.commit();
        }
    }

    // Alt let go before the switcher had the keyboard (a quick tap) sends it
    // no key release, so read what's held once it has the keyboard. If it
    // never gets it, take the tap anyway.
    Timer {
        interval: 16
        repeat: true
        running: Switcher.holding && root.here && root.Window.active
        onTriggered: {
            if ((Keyboard.modifiers() & Qt.AltModifier) === 0)
                Switcher.commit();
        }
    }

    Timer {
        interval: 700
        running: Switcher.holding && root.here && !root.Window.active
        onTriggered: Switcher.commit()
    }
}
