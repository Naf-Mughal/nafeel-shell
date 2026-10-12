import QtQuick
import qs.services

Text {
    color: Colours.palette.m3onSurface
    renderType: Text.NativeRendering

    Behavior on color {
        CAnim {}
    }
}
