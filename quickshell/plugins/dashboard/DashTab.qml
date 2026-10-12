import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components
import qs.modules.commandcenter.tabs

// The dashboard tab, Caelestia's grid:
//   weather  | you                   | media
//   clock | calendar     | resources |  (tall)
GridLayout {
    id: root

    columns: 6
    rows: 2
    rowSpacing: Tokens.spacing.normal
    columnSpacing: Tokens.spacing.normal

    WeatherCard {
        Layout.row: 0
        Layout.column: 0
        Layout.columnSpan: 2
        Layout.preferredWidth: 300
        Layout.preferredHeight: 110
    }

    UserCard {
        Layout.row: 0
        Layout.column: 2
        Layout.columnSpan: 3
        Layout.fillWidth: true
        Layout.preferredHeight: 110
    }

    MediaCard {
        Layout.row: 0
        Layout.column: 5
        Layout.rowSpan: 2
        Layout.preferredWidth: 230
        Layout.fillHeight: true
    }

    ClockCard {
        Layout.row: 1
        Layout.column: 0
        Layout.preferredWidth: 112
        Layout.fillHeight: true
    }

    Surface {
        Layout.row: 1
        Layout.column: 1
        Layout.columnSpan: 3
        Layout.fillWidth: true
        Layout.fillHeight: true
        level: 2

        CalendarTab {
            anchors.fill: parent
            anchors.margins: Tokens.spacing.normal
        }
    }

    ResourcesCard {
        Layout.row: 1
        Layout.column: 4
        Layout.preferredWidth: 168
        Layout.fillHeight: true
    }
}
