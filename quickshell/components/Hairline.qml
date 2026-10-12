import QtQuick
import qs.config
import qs.services

// A 1px rule in faint ink: depth is a line, not a shadow.
Rectangle {
    property bool vertical: false

    implicitWidth: vertical ? Tokens.hairline : 0
    implicitHeight: vertical ? 0 : Tokens.hairline
    color: Qt.alpha(Colours.palette.m3onSurface, 0.13)
}
