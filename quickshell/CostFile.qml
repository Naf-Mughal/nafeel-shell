//@ pragma UseQApplication
import QtQuick
import Quickshell
import Nafeel
import qs.components
import qs.config

// Live-heap cost of a component file (a measuring tool; scratch cost-file.sh):
// builds COST_N of COST_URL (relative to this folder), hidden, 2 s after
// start, and logs jemalloc's allocated MB before and after.
FloatingWindow {
    id: root

    implicitWidth: 900
    implicitHeight: 700
    color: "black"
    title: "costfile"

    readonly property string url: Quickshell.env("COST_URL")
    readonly property int n: parseInt(Quickshell.env("COST_N") || "1")
    property real before: 0
    property var made: []

    function alloc(): real {
        return JSON.parse(Memory.stats()).allocated;
    }

    Timer {
        interval: 3500; running: true
        onTriggered: {
            root.before = root.alloc();
            const c = Qt.createComponent(root.url);
            if (c.status !== Component.Ready) {
                console.log("COSTRESULT error " + c.errorString());
                Qt.quit();
                return;
            }
            for (let i = 0; i < root.n; i++) {
                const o = c.createObject(holder, { width: 800, height: 600 });
                if (!o) {
                    console.log("COSTRESULT createObject failed: " + c.errorString());
                    Qt.quit();
                    return;
                }
                root.made.push(o);
            }
            settle.start();
        }
    }
    Timer {
        id: settle
        interval: 2500
        onTriggered: {
            gc();
            final.start();
        }
    }
    Timer {
        id: final
        interval: 1500
        onTriggered: {
            console.log("COSTRESULT " + root.url + " n=" + root.n + " heap +" + (root.alloc() - root.before).toFixed(2) + " MB = " + ((root.alloc() - root.before) / root.n * 1024).toFixed(0) + " KB each");
            Qt.quit();
        }
    }

    Item {
        id: holder
        visible: false
        width: 800
        height: 600
    }
}
