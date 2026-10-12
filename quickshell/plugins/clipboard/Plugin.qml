import QtQuick
import Nafeel

// The clipboard plugin: the history is kept from the start, not only once
// its panel first shows it.
QtObject {
    readonly property var clipboard: Clipboard
}
