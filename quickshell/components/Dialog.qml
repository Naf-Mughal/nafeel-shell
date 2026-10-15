import QtQuick
import qs.config
import qs.services

// A question that needs an answer ("Forget this device?"): in the middle of
// its panel over a dim, unfolding from the middle (Floating). Enter
// confirms, Esc or a press outside cancels. `danger` puts the confirm in the
// error colour.
//   Dialog { id: d; from: someItem; title: "Forget Pixel Buds?"; text: "…";
//            confirmText: "Forget"; danger: true; onAccepted: … }   … d.show()
Floating {
    id: root

    property string title
    property string text
    property string confirmText: "OK"
    property string cancelText: "Cancel"
    property bool danger: false
    signal accepted
    signal rejected

    placement: "centre"
    scrim: true

    property bool answered: false
    onOpenChanged: {
        if (open)
            answered = false;
        else if (!answered)
            rejected();
    }
    onKeyPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            answer(true);
            event.accepted = true;
        }
    }

    function answer(yes: bool): void {
        answered = true;
        if (yes)
            accepted();
        else
            rejected();
        open = false;
    }

    card.implicitWidth: 340
    card.implicitHeight: body.implicitHeight + Tokens.spacing.large * 2

    Column {
        id: body

        x: Tokens.spacing.large
        y: Tokens.spacing.large
        width: root.card.width - Tokens.spacing.large * 2
        spacing: Tokens.spacing.normal

        StyledText {
            width: parent.width
            text: root.title
            color: Colours.palette.m3onSurface
            font.family: Tokens.font.serif
            font.pixelSize: Tokens.font.value
            wrapMode: Text.Wrap
        }

        StyledText {
            width: parent.width
            visible: text !== ""
            text: root.text
            color: Colours.palette.m3onSurfaceVariant
            font.pixelSize: Tokens.font.body
            wrapMode: Text.Wrap
        }

        Row {
            anchors.right: parent.right
            spacing: Tokens.spacing.small

            Surface {
                interactive: true
                emphasis: "ghost"
                implicitWidth: cancel.implicitWidth + Tokens.spacing.large * 2
                implicitHeight: 36
                shape: "small"
                onClicked: root.answer(false)

                StyledText {
                    id: cancel

                    anchors.centerIn: parent
                    text: root.cancelText
                    color: parent.ink
                    font.pixelSize: Tokens.font.body
                    font.weight: Font.DemiBold
                }
            }

            Surface {
                interactive: true
                role: root.danger ? "error" : "primary"
                emphasis: "strong"
                implicitWidth: confirm.implicitWidth + Tokens.spacing.large * 2
                implicitHeight: 36
                shape: "small"
                onClicked: root.answer(true)

                StyledText {
                    id: confirm

                    anchors.centerIn: parent
                    text: root.confirmText
                    color: parent.ink
                    font.pixelSize: Tokens.font.body
                    font.weight: Font.DemiBold
                }
            }
        }
    }
}
