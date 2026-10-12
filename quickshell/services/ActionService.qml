import QtQuick
import Quickshell

// The base of a service whose panel picks things and applies them when it
// closes: the wallpaper picker stages a wallpaper while you browse (the
// service can get ready for it meanwhile: the palette is made in the
// background), and closing the picker commits it, so the change lands at
// once, as one shell-wide ink transition.
//
// A service holds one (a Singleton can't be built on another type):
//
//   readonly property ActionService act: ActionService {
//       name: "wallpaper"; drawer: "wallpapers"
//       actions: ({ set: path => …, random: () => … })
//       prepare: ({ set: path => … })        // optional: on stage
//   }
//
//   Wallpapers.act.stage("set", path)    // the picker
//   Wallpapers.act.run("set", path)      // at once (IPC, keybinds)
//
// Bus: "<name>.staged" { action, args }, "<name>.committed" { action, args },
// "<name>.discarded".
QtObject {
    id: root

    // The topic prefix on the Bus.
    property string name
    // The drawer whose closing commits what's staged ("" = commit by hand).
    property string drawer
    // action -> function(args): does it.
    property var actions: ({})
    // action -> function(args): gets ready for it (optional).
    property var prepare: ({})

    // What's staged: { action, args } or null. One at a time: staging again
    // replaces it (the last wallpaper you picked is the one that's set).
    property var staged: null
    readonly property bool hasStaged: staged !== null

    function stage(action: string, args: var): void {
        if (!actions[action]) {
            console.warn(`${name}: no action "${action}"`);
            return;
        }
        staged = {
            action,
            args
        };
        // (No optional call here: Qt 6.12's compiler crashes on `f?.()`.)
        const ready = prepare[action];
        if (ready)
            ready(args);
        Bus.publish(`${name}.staged`, staged);
    }

    function commit(): void {
        const s = staged;
        if (!s)
            return;
        staged = null;
        actions[s.action](s.args);
        Bus.publish(`${name}.committed`, s);
    }

    function discard(): void {
        if (!staged)
            return;
        staged = null;
        Bus.publish(`${name}.discarded`, {});
    }

    function run(action: string, args: var): void {
        stage(action, args);
        commit();
    }

    // The panel closed: what it staged happens now.
    property bool _open: drawer !== "" && (ShellState.pinned === drawer || ShellState.previewed === drawer)
    on_OpenChanged: if (!_open)
        commit()
}
