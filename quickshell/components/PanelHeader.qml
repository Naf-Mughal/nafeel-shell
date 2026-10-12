import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// A panel's heading: an icon badge (a Surface in the secondary role), the
// title with its Chinese gloss, a subtitle, and trailing actions.
RowLayout {
    id: root

    property string icon
    property string title
    property string gloss
    property string subtitle
    default property alias trailing: end.data
    // Something centred in the room between the title and the actions (the
    // dashboard's OSD); the title then keeps to its own width.
    property alias middle: mid.data

    spacing: Tokens.spacing.normal

    Surface {
        Layout.preferredWidth: 40
        Layout.preferredHeight: 40
        role: "secondary"

        MaterialIcon {
            anchors.centerIn: parent
            text: root.icon
            fill: 1
            color: parent.ink
        }
    }

    ColumnLayout {
        Layout.fillWidth: !mid.visible
        spacing: 0

        GlossTitle {
            Layout.fillWidth: true
            text: root.title
            gloss: root.gloss
            size: Tokens.font.value
        }

        StyledText {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.subtitle
            color: Colours.palette.m3onSurfaceVariant
            font.pixelSize: Tokens.font.small
            elide: Text.ElideRight
        }
    }

    Item {
        id: mid

        visible: children.length > 0
        Layout.fillWidth: true
        Layout.fillHeight: true
    }

    Item {
        id: end

        Layout.preferredWidth: childrenRect.width
        Layout.preferredHeight: childrenRect.height
    }
}
