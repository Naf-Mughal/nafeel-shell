pragma Singleton

// How the shell writes the time: 12-hour (1:05 PM) or 24-hour (13:05), as
// set on the Settings panel's Time & units page. Everything that shows a
// time goes through here.
//
//   Time.time(d)      "1:05 PM" | "13:05"
//   Time.hour(d)      "1 PM" | "13"
//   Time.hours(d)     the bar's stacked hour: "01" | "13"
//   Time.meridiem(d)  "PM" | "" (24-hour)

import QtQuick
import Quickshell
import qs.config

Singleton {
    id: root

    readonly property SettingsPage settings: SettingsPage {
        name: "time"
        title: "Time & units"
        gloss: "时令"
        icon: "schedule"
        order: 60
        description: "How times, temperatures and speeds are written."

        SettingItem {
            key: "time.24h"
            kind: "toggle"
            icon: "schedule"
            label: "24-hour clock"
            description: "13:05 instead of 1:05 PM, wherever the shell shows the time."
            def: false
        }
        SettingItem {
            key: "units.temperature"
            section: "Units"
            label: "Temperature"
            description: "For the weather everywhere it shows."
            def: "c"
            options: [
                {
                    value: "c",
                    icon: "thermostat",
                    label: "Celsius"
                },
                {
                    value: "f",
                    icon: "device_thermostat",
                    label: "Fahrenheit"
                }
            ]
        }
        SettingItem {
            key: "units.speed"
            label: "Wind speed"
            def: "kmh"
            options: [
                {
                    value: "kmh",
                    icon: "air",
                    label: "km/h"
                },
                {
                    value: "mph",
                    icon: "air",
                    label: "mph"
                },
                {
                    value: "ms",
                    icon: "air",
                    label: "m/s"
                }
            ]
        }
    }

    readonly property bool h24: settings.v["time.24h"] === true
    readonly property bool fahrenheit: settings.v["units.temperature"] === "f"
    readonly property string speedUnit: settings.v["units.speed"]

    function time(d: date): string {
        return Qt.formatTime(d, h24 ? "HH:mm" : "h:mm AP");
    }

    function hour(d: date): string {
        return Qt.formatTime(d, h24 ? "HH" : "h AP");
    }

    function hours(d: date): string {
        return h24 ? Qt.formatTime(d, "HH") : Qt.formatTime(d, "hh AP").split(" ")[0];
    }

    function meridiem(d: date): string {
        return h24 ? "" : Qt.formatTime(d, "AP");
    }

    // A temperature in °C, written in the chosen unit: "21°".
    function deg(celsius: real): string {
        return `${Math.round(fahrenheit ? celsius * 9 / 5 + 32 : celsius)}°`;
    }

    // A speed in km/h, written in the chosen unit: "12 km/h".
    function speed(kmh: real): string {
        if (speedUnit === "mph")
            return `${Math.round(kmh / 1.609)} mph`;
        if (speedUnit === "ms")
            return `${Math.round(kmh / 3.6)} m/s`;
        return `${Math.round(kmh)} km/h`;
    }
}
