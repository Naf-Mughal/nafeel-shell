import QtQuick
import qs.config
import qs.services

// A titled section of a panel: the heading (Latin name, its Chinese gloss,
// an optional tracked eyebrow above and trailing actions on the right), then
// its content, on the standard spacing. Children go in the content.
//
//   Sheet { title: "Volume"; gloss: "声音"; Slider { … } }
Column {
    id: root

    property string title
    property string gloss
    property string eyebrow
    // The heading's size: "section" (in a panel) | "panel" (a panel's own).
    property string level: "section"
    default property alias content: body.data
    property alias trailing: actions.data

    spacing: Tokens.spacing.small

    MicroLabel {
        visible: root.eyebrow !== ""
        text: root.eyebrow
    }

    Item {
        visible: root.title !== "" || actions.children.length > 0
        width: parent.width
        height: Math.max(heading.implicitHeight, actions.implicitHeight)

        GlossTitle {
            id: heading

            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            gloss: root.gloss
            size: root.level === "panel" ? Tokens.font.value : Tokens.font.row
        }

        Row {
            id: actions

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.spacing.small
        }
    }

    Column {
        id: body

        width: parent.width
        spacing: Tokens.spacing.small
    }
}
