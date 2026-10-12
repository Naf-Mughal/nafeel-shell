import QtQuick

// A feature's settings, declared beside it (see Settings): what the Settings
// panel shows as one page, and where the feature reads its values from.
//
//   v        every key's value: what's stored, else its default
//   order    the page's place in the panel's list (or, sharing another
//            feature's page name, where its items go on that page)
QtObject {
    id: root

    property string name
    property string title
    property string gloss
    property string icon: "settings"
    property string description
    property int order: 100
    default property list<SettingItem> items
    // Items made at runtime (the Plugins page lists whatever plugins exist).
    property var extraItems: []
    readonly property var allItems: Array.from(items).concat(extraItems)

    readonly property var v: {
        const stored = Settings.values;
        const out = {};
        for (const item of allItems)
            out[item.key] = item.key in stored ? stored[item.key] : item.def;
        return out;
    }

    Component.onCompleted: Settings.register(root)
    // A plugin switched off takes its page with it.
    Component.onDestruction: Settings.unregister(root)
}
