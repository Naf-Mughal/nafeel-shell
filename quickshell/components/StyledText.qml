import QtQuick
import qs.services

// Text in the shell's ink. No colour animation of its own: a theme change
// soaks in under the ink transition (InkStill), and a Behavior per text was
// ~23 000 objects made for nothing.
Text {
    color: Colours.palette.m3onSurface
    renderType: Text.NativeRendering
}
