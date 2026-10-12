import QtQuick
import "modules/lock/themes/xianxia"

// The login screen (an SDDM theme): the shell's own lock surface, cave
// abode, with SDDM doing the login. Everything it shows comes from the shell
// (its exported GreeterData.qml: palette, type, wallpaper, avatar,
// cultivation), so it's the same world as the desktop. Built by
// bin/nafeel-greeter from these files and the shell's lock (shared, not
// copied by hand).
Item {
    id: root

    // Where the shell exports for the greeter (theme.conf).
    readonly property string dataDir: config.dataDir || "/var/lib/nafeel-greeter"

    width: 1920
    height: 1080

    Loader {
        id: exported

        source: "file://" + root.dataDir + "/GreeterData.qml"
    }

    GreeterHost {
        id: greeterHost

        data: exported.item
        dir: root.dataDir
    }

    GreeterContext {
        id: greeterCtx

        userName: exported.item?.userName || userModel.lastUser || ""
        sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
        h24: exported.item?.h24 ?? false
        preview: config.testMode === "true"
    }

    Connections {
        target: sddm

        function onLoginFailed() {
            greeterCtx.loginFailed();
        }

        function onLoginSucceeded() {
            greeterCtx.loginSucceeded();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    // (Made afresh when test mode starts over. The ids differ from the
    // surface's property names: `ctx: ctx` would bind the property to itself.)
    Loader {
        id: surface

        anchors.fill: parent
        sourceComponent: XianxiaSurface {
            ctx: greeterCtx
            host: greeterHost
            shown: true
        }
    }

    Connections {
        target: greeterCtx

        function onRestarted() {
            surface.active = false;
            surface.active = true;
        }
    }
}
