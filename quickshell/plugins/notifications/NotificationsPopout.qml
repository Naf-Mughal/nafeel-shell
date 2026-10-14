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

    // The history, virtualised: only the cards in view (and a screen's
    // worth around) are made, not all of it (up to 100, kept warm here and
    // in the command center's tab).
    Strip {
        id: cards

        width: parent.width
        height: Math.min(contentHeight, 460)
        visible: root.notifs.history.length > 0
        orientation: ListView.Vertical
        spacing: Tokens.spacing.small
        cacheBuffer: 400
        model: root.notifs?.historyModel ?? null

        // By key (historyModel): a change moves or adds a card, never
        // rebuilds them all.
        delegate: NotificationCard {
            id: card

            required property int key
            required property int revision
            // The last known entry, for a card on its way out.
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

            width: cards.width
            rev: revision
            entry: {
                const found = root.notifs?.byKey(key);
                if (found)
                    card.last = found;
                return found ?? card.last;
            }
        }
    }
}
