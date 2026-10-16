import Quickshell
import qs.modules.frame
import qs.modules.background

// The wallpaper and the frame (bar, drawers, panels), loaded by shell.qml
// once the plugins' roots are up (its panels use them as they're made).
Scope {
    Background {}
    Frame {}
}
