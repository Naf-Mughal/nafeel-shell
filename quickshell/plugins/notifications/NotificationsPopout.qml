pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.components

// Notification history, newest first, with do not disturb and clear all in
// the header. Showing it marks everything seen.
Panel {
    id: root

    // The notifications plugin's server (the bar hides this panel's bell
    // while it's off).
    readonly property var notifs: Plugins.instance("notifications")?.notifs ?? null


    Component.onCompleted: root.notifs.markSeen()

    PanelHeader {
        width: parent.width
        gloss: Xian.gloss.notifications
        icon: root.notifs.dnd ? "notifications_off" : "notifications"
        title: "Notifications"
        subtitle: root.notifs.history.length > 0 ? `${root.notifs.history.length} in history` : "All caught up"

        Row {
            spacing: Tokens.spacing.small

            IconButton {
                icon: "do_not_disturb_on"
                filled: root.notifs.dnd
                size: 36
                onClicked: root.notifs.toggleDnd()
            }

            IconButton {
                icon: "clear_all"
                size: 36
                onClicked: root.notifs.clear()
            }
        }
    }

    EmptyState {
        width: parent.width
        visible: root.notifs.history.length === 0
        icon: "notifications_paused"
        title: "All quiet"
        hint: root.notifs.dnd ? "Do not disturb is on" : "No messages have arrived"
    }

    Scroller {
        width: parent.width
        height: Math.min(cards.implicitHeight, 460)
        visible: root.notifs.history.length > 0
        contentHeight: cards.implicitHeight
        clip: true

        Column {
            id: cards

            width: parent.width
            spacing: Tokens.spacing.small

            Repeater {
                model: root.notifs.history

                NotificationCard {
                    required property var modelData

                    width: cards.width
                    entry: modelData
                }
            }
        }
    }
}
