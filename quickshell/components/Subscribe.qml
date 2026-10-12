import QtQuick
import qs.services

// Listens to one Bus topic ("theme.ready") or a family ("wallpaper.*").
// A retained topic is delivered at once on creation too.
//
//   Subscribe { topic: "theme.ready"; onReceived: payload => … }
QtObject {
    id: root

    property string topic
    property bool enabled: true

    signal received(var payload, string topic)

    function matches(t: string): bool {
        return topic.endsWith(".*") ? t.startsWith(topic.slice(0, -1)) : t === topic;
    }

    readonly property Connections _c: Connections {
        target: Bus
        enabled: root.enabled

        function onPublished(t: string, payload: var): void {
            if (root.matches(t))
                root.received(payload, t);
        }
    }

    Component.onCompleted: {
        if (!enabled)
            return;
        for (const [t, payload] of Object.entries(Bus.retained))
            if (matches(t))
                received(payload, t);
    }
}
