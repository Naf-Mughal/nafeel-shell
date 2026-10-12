import QtQuick
import Quickshell

// The apps plugin's root: Qt and KDE apps in the shell's colours (the Theme
// page's "Qt and KDE apps" section) and the default apps (the Default apps
// page). Switched off, neither writes anything any more (what they wrote
// stays as it was).
Scope {
    readonly property AppTheming theming: AppTheming {}
    readonly property DefaultApps defaults: DefaultApps {}
}
