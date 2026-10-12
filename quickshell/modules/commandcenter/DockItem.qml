pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.components

// A dock app: its icon, and on its corner a badge with how many windows it
// has open (the accent while focused).
// Click focuses it (again cycles its windows) or starts it, middle-click
// starts another, right-click pins/unpins. Resting on a running one shows
// live previews of its windows above the dock.
Item {
    id: root

    required property var modelData
    property bool expanded
    property string screenName: ""

    readonly property bool running: modelData.windows.length > 0
    readonly property bool focused: modelData.windows.some(w => w.focused)
    readonly property var entry: Apps.forAppId(modelData.appId)

    width: 52
    height: 64

    // Its icon: a tile in the theme's colours (AppIcon), stronger while
    // hovered; no scaling.
    // Every icon the same box, centred in the dock's height.
    AppIcon {
        id: icon

        anchors.centerIn: parent
        size: Dock.settings.v["dock.iconSize"]
        appId: root.modelData.appId
        hovered: hover.hovered || root.previewing
    }

    // Running: a badge (a round Surface) on the icon's top-right corner with
    // how many windows are open in Chinese numerals, 一 二 三 … 十, then 多
    // (many), in the CJK serif; always the same size, strong in the primary
    // role while the app has focus. Nothing sits under the icons, so the
    // row stays even.
    Surface {
        id: badge

        readonly property int count: root.modelData.windows.length

        visible: root.running
        x: icon.x + icon.width - width / 2 - 3
        y: icon.y - height / 2 + 3
        width: 20
        height: 20
        shape: "full"
        role: root.focused ? "primary" : "secondary"
        emphasis: root.focused ? "strong" : "soft"

        StyledText {
            anchors.centerIn: parent
            text: badge.count > 10 ? "多" : badge.count === 10 ? "十" : Xian.digits[badge.count] ?? ""
            color: badge.ink
            font.family: Tokens.font.cjk
            font.pixelSize: 11
            font.weight: Font.Bold
        }
    }

    // Resting on a running app previews its windows above the dock (part of
    // the dock's panel: CommandCenter / DockPreview), after the Dock page's
    // delay; resting on one without windows puts a preview away.
    readonly property bool previewing: ShellState.dockPreview === modelData.appId

    // A command center opened by hovering the middle symbol folds back into
    // the dock for it; one opened by a click stays.
    readonly property bool hoverOpened: root.expanded && ShellState.pinned === "" && ShellState.previewed === "command"

    Timer {
        running: hover.hovered && (!root.expanded || root.hoverOpened)
        interval: Dock.settings.v["dock.windowsDelay"]
        onTriggered: {
            if (root.hoverOpened)
                ShellState.preview("dock", root.screenName);
            ShellState.dockPreview = root.running ? root.modelData.appId : "";
            ShellState.dockPreviewScreen = root.screenName;
        }
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: tap

        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onTapped: (point, button) => {
            if (button === Qt.RightButton)
                Dock.togglePin(root.modelData.appId);
            else if (button === Qt.MiddleButton)
                root.entry?.execute();
            else
                Dock.activate(root.modelData);
        }
    }
}
