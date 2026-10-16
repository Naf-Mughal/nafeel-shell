import QtQuick
import Quickshell
import qs.services

// Every enabled plugin's root (its services, settings, IPC), loaded by
// shell.qml behind the entrance: a file of its own, so its types (every
// plugin's) compile as it loads, not before the shell's first frame.
Scope {
    // The theme follows the wallpaper from the start.
    readonly property var theme: Theme
    // The battery's saver and warnings run whether or not a panel shows.
    readonly property var power: Power
    // Every plugin that's on has its root (shell.qml makes the desktop then).
    readonly property bool started: Plugins.started

    // A plugin that's off loads nothing.
    // A loader per plugin with a root, over every plugin found (a model that
    // only changes on a rescan), so switching one plugin starts or stops just
    // its own root; the rest keep their state.
    Instantiator {
        model: Plugins.withRoot

        delegate: Loader {
            required property var modelData

            active: Plugins.isEnabled(modelData.id)
            source: Plugins.urlOf(modelData, modelData.root)
            onLoaded: Plugins.attach(modelData.id, item)
            onActiveChanged: if (!active)
                Plugins.attach(modelData.id, null)
            Component.onDestruction: Plugins.attach(modelData.id, null)
        }
    }

    PluginModules {}
}
