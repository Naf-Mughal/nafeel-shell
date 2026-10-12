import QtQuick
import qs.config

// The root of a panel: its heading (when it has a title) and then its
// sections, on the panel rhythm. Everything else a panel needs comes from the
// frame: where it grows from, the morph between panels sharing a corner, the
// joins into the bars, and the ink-soak reveal.
//
//   Panel {
//       icon: "volume_up"; title: "Sound"; gloss: Xian.gloss.audio; subtitle: "…"
//       Surface { … }   // the sections, top to bottom
//   }
Column {
    id: root

    property string icon
    property string title
    property string gloss
    property string subtitle
    // "comfortable" (the usual) | "compact" (dense lists).
    property string density: "comfortable"
    property alias actions: header.trailing
    property alias middle: header.middle
    // What gets the keyboard when the panel is pinned (a search field, say);
    // CornerPopout hands it over.
    property Item focusTarget: null

    function takeFocus(): bool {
        if (!focusTarget)
            return false;
        if (focusTarget.focusInput)
            focusTarget.focusInput();
        else
            focusTarget.forceActiveFocus();
        return true;
    }

    spacing: density === "compact" ? Tokens.spacing.small : Tokens.spacing.normal

    PanelHeader {
        id: header

        visible: root.title !== ""
        width: parent.width
        icon: root.icon
        title: root.title
        gloss: root.gloss
        subtitle: root.subtitle
    }
}
