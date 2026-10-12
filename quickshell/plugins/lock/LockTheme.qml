pragma Singleton
import QtQuick

// Shared helpers for the lock surface. Trimmed from the reference shell's
// matugen-driven HUD palette: Cave Abode brings its own colours (Xian.qml).
// No shell imports: the SDDM theme shares this file.
QtObject {
    readonly property string icons: "Material Symbols Rounded"
    readonly property color ink: "#eadfc6"

    // Eased 0..1 slice of a 0..1 timeline: how far an element whose entrance
    // runs from `from` to `to` has got when the whole choreography is at `p`.
    function seg(p, from, to) {
        const x = Math.max(0, Math.min(1, (p - from) / (to - from)));
        return 1 - Math.pow(1 - x, 3);
    }
}
