import QtQuick
import qs.config
import qs.services

// A round Material icon button (a Surface). `filled` uses the colour pair as
// a solid fill; otherwise it's a tonal button on the paper. A `caption` (a
// level, say) sits small under the icon. With an `appId` the app's icon
// stands in for the Material one. Pressed, its icon dips and fills in, then
// springs back; a caption that changes rolls (RollText).
Surface {
    id: root

    property string icon
    property bool filled: false
    property color fillColour: Colours.palette.m3secondaryContainer
    property color inkColour: Colours.palette.m3onSecondaryContainer
    property int size: 40
    property string caption: ""
    property string appId: ""

    interactive: true
    pressDepth: 0.9
    implicitWidth: size
    implicitHeight: size
    // Tonal: a step above the paper with a hairline, so it reads as a button.
    fill: filled ? fillColour : Colours.roleFill("paper", "soft", 4)
    outlined: !filled
    // Under a hold's ink (holdToConfirm), the ink of the fill.
    baseInk: holding ? Colours.roleInk("primary", "strong") : filled ? inkColour : Colours.palette.m3onSurface
    // M3 Expressive shape morph: rounder at rest, squarer while pressed.
    shapeRadius: pressed ? Tokens.rounding.small : Math.min(size / 2, Tokens.rounding.morph)

    Column {
        anchors.centerIn: parent
        // A glyph has room around it; an app's icon fills its box.
        spacing: root.appId !== "" ? 1 : -2

        // Built only for an app's icon (most buttons have none): an
        // AppIcon always made, hidden, held a Material icon, an Image of the
        // placeholder icon and a tint Loader in every button.
        Loader {
            anchors.horizontalCenter: parent.horizontalCenter
            active: root.appId !== ""
            visible: active
            sourceComponent: AppIcon {
                appId: root.appId
                size: Math.round(root.size * (root.caption ? 0.36 : 0.55))
            }
        }

        MaterialIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.appId === ""
            text: root.icon
            fill: root.filled || root.pressed ? 1 : 0
            color: root.ink
            size: Math.round(root.size * (root.caption ? 0.4 : 0.5))
            scale: root.pressed ? 0.82 : 1

            Behavior on scale {
                enabled: !Tokens.reduceMotion
                SpringAnimation {
                    spring: Tokens.spring.bouncy.spring
                    damping: Tokens.spring.bouncy.damping
                    epsilon: 0.005
                }
            }
        }

        // Made when there is a caption: a RollText (a Text per character)
        // that was empty in nearly every button.
        Loader {
            anchors.horizontalCenter: parent.horizontalCenter
            active: root.caption !== ""
            visible: active
            sourceComponent: RollText {
                text: root.caption
                color: root.ink
                font.family: Tokens.font.mono
                font.pixelSize: Math.round(root.size * 0.25)
                font.weight: Font.DemiBold
            }
        }
    }
}
