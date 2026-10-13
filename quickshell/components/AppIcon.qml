import QtQuick
import Quickshell
import qs.config
import qs.services

// An app's icon in the shell's look, every one the same size and coloured
// from the palette, so it changes with the theme; no tile behind it:
//   "themed"   the symbol for the app's kind (a browser's globe, a
//              terminal's prompt, a folder for the file manager: from the
//              desktop entry's categories, Apps.kind) in that kind's colour
//              role; an app of no known kind gets its own icon, tinted
//   "tinted"   every app's own icon, tinted to its kind's colour
//   "original" the app's own icon as it is
// Hovered, it's at full strength; at rest a touch softer. The style is the
// Dock page's icon style unless set.
Item {
    id: root

    required property string appId
    property int size: 44
    property string style: Dock.settings.v["dock.iconStyle"]
    property bool hovered: false

    readonly property var kind: Apps.kind(appId)
    readonly property bool glyph: style === "themed" && kind !== null
    readonly property bool tint: style !== "original" && !glyph
    readonly property color ink: Colours.roleInk(kind?.role ?? "primary", "ghost")

    implicitWidth: size
    implicitHeight: size
    opacity: hovered ? 1 : 0.86

    Behavior on opacity {
        Anim {
            duration: Tokens.anim.fast
        }
    }

    MaterialIcon {
        anchors.centerIn: parent
        visible: root.glyph
        text: root.kind?.glyph ?? ""
        size: root.size
        fill: 1
        color: root.ink
    }

    // The app's own icon: shown as it is, or the source of its tint.
    Image {
        id: own

        anchors.centerIn: parent
        width: root.size
        height: root.size
        sourceSize: Qt.size(root.size, root.size)
        fillMode: Image.PreserveAspectFit
        source: root.glyph ? "" : Apps.icon(root.appId)
        visible: !root.glyph && !root.tint
    }

    // The app's own icon in its kind's colour: a shader on the icon's own
    // texture, made only for a tinted icon. (A MultiEffect on every icon,
    // tinted or not, was a dozen items and an offscreen copy each: ~1400 of
    // them in the launcher, dock and switcher.)
    Loader {
        anchors.centerIn: parent
        width: own.paintedWidth
        height: own.paintedHeight
        active: root.tint
        sourceComponent: ShaderEffect {
            property variant source: own
            property color ink: root.ink
            property real lift: 0.15

            fragmentShader: Qt.resolvedUrl("../shaders/tint.frag.qsb")
        }
    }
}
