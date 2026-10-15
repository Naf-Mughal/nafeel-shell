import QtQuick
import qs.config
import qs.services

// A text area: wraps its text and grows with it from `minHeight` up to
// `maxHeight`, then scrolls inside (the caret kept in view). Typing answers
// as Appearance → Typing says, like TextField (`typing` overrides it).
//   TextArea { width: 400; placeholder: "Write anything" }
StyledRect {
    id: root

    property alias text: edit.text
    property alias textItem: edit
    property string placeholder
    property real minHeight: 88
    property real maxHeight: 260
    property var typing: Tokens.typing
    readonly property real padding: Tokens.spacing.normal

    function has(style: string): bool {
        return !Tokens.reduceMotion && (typing ?? []).indexOf(style) >= 0;
    }

    function focusInput(): void {
        edit.forceActiveFocus();
    }

    implicitWidth: 320
    implicitHeight: Math.max(minHeight, Math.min(maxHeight, edit.contentHeight + padding * 2))
    radius: Tokens.rounding.small
    color: Colours.palette.m3surfaceContainerHighest
    border.width: edit.activeFocus ? 2 : 0
    border.color: Colours.palette.m3primary

    Flickable {
        id: flick

        anchors.fill: parent
        anchors.margins: root.padding
        clip: true
        contentWidth: width
        contentHeight: edit.contentHeight
        boundsBehavior: Flickable.StopAtBounds

        // Keeps the caret in view as it moves past an edge.
        function follow(r: rect): void {
            if (r.y < contentY)
                contentY = r.y;
            else if (r.y + r.height > contentY + height)
                contentY = r.y + r.height - height;
        }

        WheelScroll {
            view: flick
        }

        TextEdit {
            id: edit

            width: flick.width
            wrapMode: TextEdit.Wrap
            color: Colours.palette.m3onSurface
            selectionColor: Colours.palette.m3primary
            selectedTextColor: Colours.palette.m3onPrimary
            font.pixelSize: Tokens.font.row
            textFormat: TextEdit.PlainText
            cursorDelegate: root.has("goo") ? gooCaret : null
            onCursorRectangleChanged: flick.follow(cursorRectangle)
            Keys.onEscapePressed: ShellState.close()

            Component {
                id: gooCaret

                GooCaret {}
            }
            CaretTrail {
                target: edit
                enabled: root.has("trail")
            }
            TypingInk {
                target: edit
                enabled: root.has("ink")
                paper: root.color
            }
            TypingBrush {
                target: edit
                enabled: root.has("brush")
            }

            StyledText {
                visible: edit.text === ""
                text: root.placeholder
                color: Colours.palette.m3onSurfaceVariant
                font.pixelSize: Tokens.font.row
            }
        }
    }
}
