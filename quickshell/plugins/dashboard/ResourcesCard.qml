import QtQuick
import qs.config
import qs.services
import qs.components

// CPU, memory, GPU and disk as upright bars (Caelestia's resources).
Surface {
    id: root

    level: 2
    implicitWidth: 168

    Component.onCompleted: SystemStats.watchers++
    Component.onDestruction: SystemStats.watchers--

    Row {
        anchors.fill: parent
        anchors.margins: Tokens.spacing.normal
        spacing: Tokens.spacing.normal

        Repeater {
            model: [
                {
                    icon: "memory",
                    value: SystemStats.cpu
                },
                {
                    icon: "memory_alt",
                    value: SystemStats.mem
                },
                {
                    icon: "developer_board",
                    value: SystemStats.gpu
                },
                {
                    icon: "hard_drive",
                    value: SystemStats.disk
                }
            ].filter(r => r.value >= 0)

            Column {
                id: col

                required property var modelData

                width: (root.width - Tokens.spacing.normal * 2 - Tokens.spacing.normal * 3) / 4
                height: parent.height
                spacing: Tokens.spacing.small

                Rectangle {
                    width: 10
                    height: parent.height - icon.height - pct.height - Tokens.spacing.small * 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    radius: 5
                    color: Colours.roleFill("secondary", "soft", 0)

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        radius: 5
                        height: parent.height * Math.max(0, Math.min(1, col.modelData.value))
                        color: Colours.roleFill(col.modelData.value > 0.85 ? "error" : "primary", "strong", 0)

                        Behavior on height {
                            Anim {}
                        }
                    }
                }

                MaterialIcon {
                    id: icon

                    anchors.horizontalCenter: parent.horizontalCenter
                    text: col.modelData.icon
                    size: 16
                    color: root.subInk
                }

                MicroLabel {
                    id: pct

                    anchors.horizontalCenter: parent.horizontalCenter
                    text: `${Math.round(col.modelData.value * 100)}`
                }
            }
        }
    }
}
