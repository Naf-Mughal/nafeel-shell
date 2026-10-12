import QtQuick
import qs.config
import qs.services

// A tracked, uppercase mono label: section eyebrows, units, corner tags.
StyledText {
    color: Colours.palette.m3outline
    font.family: Tokens.font.mono
    font.pixelSize: Tokens.font.micro
    font.letterSpacing: Tokens.font.trackLabel
    font.capitalization: Font.AllUppercase
}
