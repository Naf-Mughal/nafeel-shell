pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// CPU, memory and temperature as rings, plus the machine's basics.
Item {
    id: root

    Component.onCompleted: SystemStats.watchers++
    Component.onDestruction: SystemStats.watchers--

    Row {
        id: rings

        width: parent.width
        spacing: Tokens.spacing.normal

        Ring {
            label: "CPU"
            value: SystemStats.cpu
            text: `${Math.round(SystemStats.cpu * 100)}%`
        }
        Ring {
            label: "Memory"
            value: SystemStats.mem
            text: `${(SystemStats.memUsed / 1073741824).toFixed(1)} GB`
            sub: `of ${(SystemStats.memTotal / 1073741824).toFixed(1)} GB`
        }
        Ring {
            label: "Temperature"
            value: Math.min(1, SystemStats.temp / 100)
            text: `${Math.round(SystemStats.temp)}°C`
            warn: SystemStats.temp >= 85
        }
    }

    Column {
        anchors.top: rings.bottom
        anchors.topMargin: Tokens.spacing.large
        width: parent.width
        spacing: 2

        Fact {
            icon: "computer"
            label: "Host"
            value: `${Session.user}@${Session.host}`
        }
        Fact {
            icon: "schedule"
            label: "Uptime"
            value: Session.formatUptime()
        }
        Fact {
            icon: "desktop_windows"
            label: "Compositor"
            value: `umbriel · ${Umbriel.windows.length} windows on ${Umbriel.workspaces.filter(w => w.occupied).length} workspaces`
        }
    }

    component Ring: StyledRect {
        id: ring

        property string label
        property real value
        property string text
        property string sub
        property bool warn

        width: (root.width - Tokens.spacing.normal * 2) / 3
        height: 190
        radius: Tokens.rounding.large
        color: Colours.palette.m3surfaceContainerHigh

        Canvas {
            id: canvas

            anchors.horizontalCenter: parent.horizontalCenter
            y: Tokens.spacing.large
            width: 120
            height: 120

            property real shown: ring.value
            property color track: Colours.palette.m3secondaryContainer
            property color fill: ring.warn ? Colours.palette.m3error : Colours.palette.m3primary

            Behavior on shown {
                Anim {}
            }

            onShownChanged: requestPaint()
            onTrackChanged: requestPaint()
            onFillChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.lineWidth = 12;
                ctx.lineCap = "round";
                const c = width / 2, r = c - 8, start = Math.PI * 0.75, sweep = Math.PI * 1.5;
                ctx.strokeStyle = track;
                ctx.beginPath();
                ctx.arc(c, c, r, start, start + sweep);
                ctx.stroke();
                ctx.strokeStyle = fill;
                ctx.beginPath();
                ctx.arc(c, c, r, start, start + sweep * Math.max(0.001, Math.min(1, shown)));
                ctx.stroke();
            }

            Column {
                anchors.centerIn: parent

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: ring.text
                    font.pixelSize: 18
                    font.weight: Font.Bold
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: ring.sub !== ""
                    text: ring.sub
                    color: Colours.palette.m3onSurfaceVariant
                    font.pixelSize: 10
                }
            }
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Tokens.spacing.normal
            text: ring.label
            color: Colours.palette.m3onSurfaceVariant
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
    }

    component Fact: ListRow {
        property string label
        property string value

        width: root.width
        title: value
        subtitle: label
    }
}
