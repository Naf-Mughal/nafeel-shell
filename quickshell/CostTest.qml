//@ pragma UseQApplication
import QtQuick
import Quickshell
import Nafeel
import qs.components
import qs.config

// Per-instance memory of one primitive (bin-free, a measuring tool): builds
// COST_N of COST_WHAT (hidden, as warm panels are) after 4 s; sample the
// process's PSS before and after (scratchpad cost.sh).
FloatingWindow {
    id: root

    implicitWidth: 600
    implicitHeight: 400
    color: "black"
    title: "costtest"

    readonly property string what: Quickshell.env("COST_WHAT")
    readonly property int n: parseInt(Quickshell.env("COST_N") || "200")
    property bool go: false

    property real before: 0
    function alloc() { return JSON.parse(Memory.stats()).allocated; }
    Timer {
        interval: 3500; running: true
        onTriggered: { root.before = root.alloc(); root.go = true; report.start(); }
    }
    Timer {
        id: report
        interval: 3500
        onTriggered: {
            gc();
            final.start();
        }
    }
    Timer {
        id: final
        interval: 1500
        onTriggered: {
            const d = root.alloc() - root.before;
            console.log("COSTRESULT " + root.what + " n=" + root.n + " heap +" + d.toFixed(2) + " MB = " + (d / root.n * 1024).toFixed(1) + " KB each");
            Qt.quit();
        }
    }
    Component.onCompleted: {}

    Item {
        visible: false
        width: 400; height: 300

        Repeater {
            model: root.go ? root.n : 0
            delegate: Loader {
                sourceComponent: ({
                    "text": text, "icon": icon, "rolltext": rolltext, "gloss": gloss, "chip": chip,
                    "group": group, "iconbutton": iconbutton, "surface": surface, "slider": slider,
                    "switch": sw, "listrow": listrow, "textfield": textfield, "item": plain, "rect": rect, "ink": inkswap, "rawtext": rawtext, "plaintext": plaintext, "boundtext": boundtext, "nativetext": nativetext, "emptytext": emptytext, "t1": t1, "t40": t40, "t3": t3, "tsized": tsized, "goo": goo, "hover": hover, "seg": seg, "group1": group1, "stack": stack
                })[root.what]
            }
        }
    }

    Component { id: rawtext; Text { text: "Hello world" } }
    Component { id: plaintext; Text { text: "Hello world"; textFormat: Text.PlainText } }
    Component { id: boundtext; Text { text: "Hello world"; color: Colours.palette.m3onSurface } }
    Component { id: nativetext; Text { text: "Hello world"; renderType: Text.NativeRendering } }
    Component { id: emptytext; Text { } }
    Component { id: goo; GooIndicator { width: 300; height: 52 } }
    Component { id: hover; HoverTracker { } }
    Component { id: seg; Surface { emphasis: "ghost"; interactive: true; hoverLayer: false; width: 100; height: 52
        Column { anchors.centerIn: parent; MaterialIcon { text: "home"; size: 18 } StyledText { text: "Label" } } } }
    Component { id: group1; ButtonGroup { model: [{ value: "a", icon: "home", label: "One" }]; current: "a" } }
    Component { id: stack; Column { MaterialIcon { text: "home"; size: 18 } StyledText { text: "Label" } } }
    Component { id: t1; Text { text: "a" } }
    Component { id: t3; Text { text: "50%" } }
    Component { id: t40; Text { text: "The quick brown fox jumps over the lazy dog" } }
    Component { id: tsized; Text { text: "Hello world"; font.pixelSize: 13; font.weight: Font.DemiBold } }
    Component { id: plain; Item { width: 10; height: 10 } }
    Component { id: rect; Rectangle { width: 10; height: 10; color: "red" } }
    Component { id: text; StyledText { text: "Hello world" } }
    Component { id: icon; MaterialIcon { text: "home" } }
    Component { id: rolltext; RollText { text: "Hello" } }
    Component { id: inkswap; InkSwap { text: "Hello" } }
    Component { id: gloss; GlossTitle { text: "Appearance"; gloss: "外观" } }
    Component { id: chip; Chip { text: "Template"; icon: "palette" } }
    Component { id: group; ButtonGroup { model: [{ value: "a", icon: "home", label: "One" }, { value: "b", icon: "star", label: "Two" }, { value: "c", icon: "bolt", label: "Three" }]; current: "a" } }
    Component { id: iconbutton; IconButton { icon: "settings" } }
    Component { id: surface; Surface { width: 60; height: 30 } }
    Component { id: slider; StyledSlider { width: 200; value: 0.4 } }
    Component { id: sw; StyledSwitch { checked: true } }
    Component { id: listrow; ListRow { icon: "wifi"; title: "Wi-Fi"; subtitle: "Connected" } }
    Component { id: textfield; TextField { width: 200 } }
}
