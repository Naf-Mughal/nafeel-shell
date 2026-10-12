import QtQuick
import qs.config
import qs.services
import qs.components

// A store result's state on its card: its resolution, then a download's
// progress along the foot, a tick once it's in your library, a cross if it
// failed.
Item {
    id: root

    required property var wall
    readonly property var shop: wall.provider === "motionbgs" ? Plugins.instance("wallpaper")?.motionbgs : Plugins.instance("wallpaper")?.wallhaven
    readonly property string state: shop.status[wall.id] ?? (shop.local[wall.id] ? "done" : "")
    readonly property real progress: shop.progress[wall.id] ?? 0

    visible: wall.remote ?? false

    Rectangle {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.spacing.small
        width: res.implicitWidth + 10
        height: res.implicitHeight + 4
        radius: 4
        color: Qt.alpha("black", 0.55)

        StyledText {
            id: res

            anchors.centerIn: parent
            text: root.wall.resolution ?? ""
            color: "white"
            font.family: Tokens.font.mono
            font.pixelSize: Tokens.font.tiny
        }
    }

    MaterialIcon {
        visible: root.state === "done" || root.state === "error"
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Tokens.spacing.small
        text: root.state === "done" ? "download_done" : "error"
        size: 18
        color: root.state === "done" ? Colours.palette.m3primary : Colours.palette.m3error
        style: Text.Outline
        styleColor: Qt.alpha("black", 0.5)
    }

    // Progress: a line of ink along the foot.
    Rectangle {
        visible: root.state === "downloading"
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        height: 3
        width: parent.width * Math.max(0.04, root.progress)
        color: Colours.palette.m3primary

        Behavior on width {
            Anim {
                duration: Tokens.anim.fast
            }
        }
    }
}
