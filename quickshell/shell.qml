//@ pragma UseQApplication
//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
// The threaded render loop: each window renders and waits for vsync on its
// own render thread, so animations and input keep their pace on the GUI
// thread (the basic loop swapped every window on it in turn).
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded

// nafeel shell: every on-screen surface of the desktop (frame, bar, drawers,
// dock, command center…) in one Quickshell process, on top of umbriel and
// Noctalia's services. Started and themed by the nafeel/shell Noctalia plugin.

import QtQuick
import Quickshell

// Nothing of the shell's own is imported here: what this file names is
// compiled before its first frame. The rest comes from files loaded after.
ShellRoot {
    id: shell

    settings.watchFiles: true

    // The session's start (bin/nafeel-shell: the first shell of a umbriel
    // session), not a restart: the login screen carried on (Entrance: the
    // grant, then the ink receding into the desktop) while the rest loads.
    readonly property bool wanted: Quickshell.env("NAFEEL_ENTRANCE") === "1"
    property bool entering: false
    // Whether it's entering is known (at once when it isn't wanted).
    property bool decided: !wanted
    // The rest waits for the entrance's first frame (alongside, that frame
    // came ~0.5 s later); never long.
    readonly property bool holding: entering && !(entrance.item?.drawn ?? false) && !holdLimit.done

    // Survives reloads: a reload isn't a login. (Its values are back once
    // it's `loaded`, after Component.onCompleted.)
    PersistentProperties {
        reloadableId: "nafeel-entrance"

        property bool played: false

        onLoaded: {
            if (shell.wanted && !played) {
                played = true;
                shell.entering = true;
                holdLimit.start();
            }
            shell.decided = true;
        }
    }

    Timer {
        id: holdLimit

        property bool done: false

        interval: 1500
        onTriggered: done = true
    }

    // Its first frame, as a picture, until it's drawn its own (and a moment
    // more: gone the moment that frame was swapped, the desktop showed
    // between the two for two frames).
    Splash {
        id: splash

        active: shell.entering && !splashGone.done
    }

    Timer {
        id: splashGone

        property bool done: false

        running: entrance.item?.drawn ?? false
        interval: 150
        onTriggered: done = true
    }

    // Made first at the session's start; otherwise after the desktop (for
    // IPC `entrance play`).
    Loader {
        id: entrance

        asynchronous: true
        active: shell.entering && (splash.drawn || !splash.known) || desktop.item !== null
        source: Qt.resolvedUrl("plugins/lock/Entrance.qml")
        onItemChanged: {
            if (!item)
                return;
            item.desktopMade = Qt.binding(() => desktop.item !== null);
            item.coverFile = splash.file;
            item.coverKnown = splash.known;
            if (shell.entering)
                item.play();
        }
    }

    // The rest is made in the background (a little at a time between
    // frames): the plugins' roots first (the panels use them as they're
    // made), then the desktop. From files of their own, compiled off this
    // thread as they load (inline, or with a LazyLoader's `source`, the whole
    // shell compiled before its first frame: ~0.8 s).
    Loader {
        id: plugins

        asynchronous: true
        active: shell.decided && !shell.holding
        source: Qt.resolvedUrl("PluginRoots.qml")
    }

    Loader {
        id: desktop

        asynchronous: true
        active: plugins.item?.started ?? false
        source: Qt.resolvedUrl("Desktop.qml")
    }
}
