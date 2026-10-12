//@ pragma UseQApplication
//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
// One render thread for every window: ~30 MB less than the threaded loop.
//@ pragma DefaultEnv QSG_RENDER_LOOP=basic

// nafeel shell: every on-screen surface of the desktop (frame, bar, drawers,
// dock, command center…) in one Quickshell process, on top of umbriel and
// Noctalia's services. Started and themed by the nafeel/shell Noctalia plugin.

import QtQuick
import Quickshell
import Nafeel
import qs.services
import qs.modules.frame
import qs.modules.background

ShellRoot {
    settings.watchFiles: true

    // The theme follows the wallpaper from the start.
    readonly property var theme: Theme
    // The battery's saver and warnings run whether or not a panel shows.
    readonly property var power: Power

    // Every enabled plugin's root (its services, settings, IPC): a plugin
    // that's off loads nothing.
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

    Background {}
    Frame {}
}
