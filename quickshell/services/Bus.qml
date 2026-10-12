pragma Singleton

// The shell's message bus: modules say what happened ("wallpaper.staged",
// "theme.ready", …) and whoever cares listens, instead of polling files or
// reaching into each other. A topic can be retained: the last message stays,
// and a new subscriber gets it at once (state, not just events).
//
//   Bus.publish("wallpaper.staged", { path })
//   Bus.retain("theme.doc", doc)                 // state topic
//   Subscribe { topic: "theme.ready"; onReceived: p => … }
//
// Topics are "<service>.<event>"; payloads are plain objects.

import QtQuick
import Quickshell

Singleton {
    id: root

    // topic -> last retained payload
    property var retained: ({})

    signal published(string topic, var payload)

    function publish(topic: string, payload: var): void {
        published(topic, payload ?? {});
    }

    function retain(topic: string, payload: var): void {
        const r = Object.assign({}, retained);
        r[topic] = payload ?? {};
        retained = r;
        published(topic, payload ?? {});
    }

    function last(topic: string): var {
        return retained[topic];
    }
}
