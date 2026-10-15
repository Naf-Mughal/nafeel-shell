import QtQuick
import qs.config
import qs.services

// A list row (a Surface, no fill until highlighted): leading icon, title and
// subtitle, trailing items. In a list with goo (`goo`: its ListGoo), the goo
// is the highlight: `picked` marks the one it rests on, and the row's ink
// turns while the goo is under it.
Surface {
    id: root

    property string icon
    property real iconFill: 0
    property string title
    property string subtitle
    property bool highlighted
    property Item goo: null
    property bool picked: false
    readonly property bool inked: goo?.covers(root) ?? false
    // The goo is the highlight (a hover-only goo leaves `highlighted` to it).
    readonly property bool gooPicks: goo !== null && !goo.hoverOnly
    default property alias trailing: end.data

    role: highlighted && !gooPicks ? "secondary" : "paper"
    emphasis: highlighted && !gooPicks ? "soft" : "ghost"
    hoverLayer: !goo
    baseInk: inked ? Colours.roleInk("secondary", "soft") : Colours.roleInk(role, emphasis)
    baseSubInk: inked ? Colours.roleSubInk("secondary", "soft") : Colours.roleSubInk(role, emphasis)
    interactive: true
    pressDepth: 1
    morph: false
    implicitHeight: 52

    MaterialIcon {
        id: lead

        anchors.left: parent.left
        anchors.leftMargin: Tokens.spacing.normal
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        fill: root.iconFill
        color: (root.highlighted && !root.gooPicks) || root.inked ? root.ink : root.subInk
    }

    Column {
        anchors.left: lead.right
        anchors.leftMargin: Tokens.spacing.normal
        anchors.right: end.left
        anchors.rightMargin: Tokens.spacing.small
        anchors.verticalCenter: parent.verticalCenter

        StyledText {
            width: parent.width
            text: root.title
            color: root.ink
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        StyledText {
            width: parent.width
            visible: text !== ""
            text: root.subtitle
            color: root.subInk
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }

    Row {
        id: end

        anchors.right: parent.right
        anchors.rightMargin: Tokens.spacing.small
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spacing.small
    }
}
