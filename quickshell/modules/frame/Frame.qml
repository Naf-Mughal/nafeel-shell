pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// One frame per screen.
Variants {
    model: Quickshell.screens

    Scope {
        id: scope

        required property ShellScreen modelData

        FrameWindow {
            screen: scope.modelData
        }
    }
}
