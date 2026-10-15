import QtQuick
import qs.config
import qs.services

// Pick one from a list: a field showing the current choice and a chevron;
// pressed, its list unfolds below it (a Menu) with the goo on the current
// one. Enter / Space / Down open it from the keyboard.
//   Select { model: [{ value, text, icon }]; current: …; onSelected: v => … }
Surface {
    id: root

    property var model: []
    property var current
    property string placeholder: "Choose…"
    signal selected(var value)

    readonly property var choice: model.find(m => m.value === current) ?? null

    interactive: true
    morph: false
    pressDepth: 0.98
    implicitWidth: 220
    implicitHeight: 40
    shape: "small"
    fill: Colours.palette.m3surfaceContainerHighest
    border.width: menu.open ? 2 : keyFocused ? 2 : 0
    border.color: Colours.palette.m3primary
    onClicked: menu.open = !menu.open
    Keys.onDownPressed: menu.show()

    Row {
        anchors.left: parent.left
        anchors.leftMargin: Tokens.spacing.normal
        anchors.right: chevron.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spacing.small

        MaterialIcon {
            visible: (root.choice?.icon ?? "") !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.choice?.icon ?? ""
            color: root.ink
            size: 18
        }

        InkSwap {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 26
            text: root.choice?.text ?? root.placeholder
            color: root.choice ? root.ink : root.subInk
            font.pixelSize: Tokens.font.body
            elide: Text.ElideRight
        }
    }

    MaterialIcon {
        id: chevron

        anchors.right: parent.right
        anchors.rightMargin: Tokens.spacing.small
        anchors.verticalCenter: parent.verticalCenter
        text: "expand_more"
        color: root.subInk
        size: 20
        rotation: menu.open ? 180 : 0

        Behavior on rotation {
            Anim {
                duration: Tokens.anim.fast
            }
        }
    }

    Menu {
        id: menu

        from: root
        model: root.model
        current: root.current
        minWidth: root.width - 8
        onPicked: v => root.selected(v)
    }
}
