pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.components
import qs.modules.bar

// The bar's capture button: opens the capture panel; right-click takes a
// region screenshot (or stops a recording), middle-click switches to
// recording (or pauses one). While recording: a red dot and the time.
BarControl {
    id: capture

    // The capture plugin's service (absent while it's off).
    readonly property var cap: Plugins.instance("capture")?.capture ?? null

    popout: "capture"
    icon: (capture.cap?.recording ?? false) ? "" : "photo_camera"
    onRightClicked: (capture.cap?.recording ?? false) ? capture.cap.request("stop") : capture.cap.request("screenshot", "region")
    onMiddleClicked: (capture.cap?.recording ?? false) ? capture.cap.request("pause") : capture.cap.request("set", "kind record")

    // Recording: a red dot and the time recorded.
    Column {
        visible: (capture.cap?.recording ?? false)
        spacing: 2

        StyledRect {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 10
            height: 10
            radius: 5
            color: (capture.cap?.paused ?? false) ? Colours.palette.m3outline : Colours.palette.m3error
        }

        StyledText {
            id: recorded

            anchors.horizontalCenter: parent.horizontalCenter
            color: capture.ink
            font.pixelSize: 10
            font.weight: Font.Bold

            Timer {
                running: (capture.cap?.recording ?? false)
                repeat: true
                interval: 1000
                triggeredOnStart: true
                onTriggered: {
                    const s = Math.floor(capture.cap.elapsed(Date.now()));
                    recorded.text = `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
                }
            }
        }
    }
}
