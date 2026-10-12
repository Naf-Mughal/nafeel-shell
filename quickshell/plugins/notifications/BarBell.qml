import QtQuick
import qs.services
import qs.modules.bar

// The bar's bell: opens the history; a dot for unread, right-click toggles
// do not disturb.
BarControl {
    readonly property var notifs: Plugins.instance("notifications")?.notifs ?? null

    popout: "notifications"
    icon: (notifs?.dnd ?? false) ? "notifications_off" : "notifications"
    dot: (notifs?.unread ?? 0) > 0
    onRightClicked: notifs?.toggleDnd()
}
