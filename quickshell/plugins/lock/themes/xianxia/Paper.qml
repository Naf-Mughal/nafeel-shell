import QtQuick

// A card on the shell's paper (its primitives' look, without the shell, so
// the login screen has it too): the panels' fill, translucent as the
// frosted-paper setting, at a card's rounding, with a hairline.
Rectangle {
    property real sc: 1

    radius: Xian.radiusNormal
    color: Xian.paperFill
    border.width: 1
    border.color: Xian.alpha(Xian.paper, 0.08)
}
