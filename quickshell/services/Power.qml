pragma Singleton

// Battery and power profile, live from UPower, and the battery's care (from
// idle-kit's power-mode and battery-warn, as shell code):
//
//   on battery     "power.battery": "boost" (default): Power Saver, and
//                  Balanced while the CPU is busy for a while (a build, tests,
//                  servers under load), back to Saver once it's been quiet a
//                  minute; "saver": Power Saver throughout; "balanced":
//                  Balanced, Power Saver below the saver level. Plugging in
//                  returns it to Balanced. A profile picked by hand stays
//                  until the next plug or unplug.
//   warnings       a notification once when the battery falls below the low
//                  level, and a critical one below the critical level.
//
// Their levels are the battery part of the Settings panel's Power & idle page.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.config

Singleton {
    id: root

    readonly property SettingsPage settings: SettingsPage {
        name: "power"
        order: 36

        SettingItem {
            key: "power.battery"
            section: "Battery"
            icon: "battery_saver"
            label: "On battery"
            description: "Saver with boost: Power Saver, and Balanced while builds, tests or servers keep the CPU busy (back to Saver after a quiet minute). Saver: Power Saver throughout. Balanced: Power Saver only below the level below."
            def: "boost"
            options: [
                {
                    value: "boost",
                    icon: "bolt",
                    label: "Saver, boost on load"
                },
                {
                    value: "saver",
                    icon: "battery_saver",
                    label: "Saver"
                },
                {
                    value: "balanced",
                    icon: "balance",
                    label: "Balanced"
                }
            ]
        }
        SettingItem {
            key: "power.saverBelow"
            kind: "number"
            label: "Battery saver below"
            description: "On battery, the power profile goes to Power Saver under this level."
            def: 30
            min: 0
            max: 60
            step: 5
            unit: "%"
            zeroLabel: "Off"
        }
        SettingItem {
            key: "power.warnLow"
            kind: "number"
            label: "Low battery warning"
            description: "Also when the battery shows as low (red) in the bar and panels."
            def: 20
            min: 0
            max: 50
            step: 5
            unit: "%"
            zeroLabel: "Off"
        }
        SettingItem {
            key: "power.warnCritical"
            kind: "number"
            label: "Critical warning"
            def: 10
            min: 0
            max: 30
            step: 1
            unit: "%"
            zeroLabel: "Off"
        }
    }

    readonly property UPowerDevice battery: UPower.displayDevice
    readonly property bool hasBattery: !!battery?.isLaptopBattery
    readonly property bool ready: hasBattery && !!battery?.ready
    readonly property real level: battery?.percentage ?? 0
    readonly property bool charging: battery?.state === UPowerDeviceState.Charging || battery?.state === UPowerDeviceState.FullyCharged || battery?.state === UPowerDeviceState.PendingCharge
    readonly property bool low: hasBattery && !charging && level * 100 <= settings.v["power.warnLow"]
    readonly property real timeToEmpty: battery?.timeToEmpty ?? 0
    readonly property real timeToFull: battery?.timeToFull ?? 0

    readonly property int percent: Math.round(level * 100)

    // ── Profile on battery ──
    readonly property string batteryMode: settings.v["power.battery"] ?? "boost"
    readonly property bool onBattery: ready && !charging
    readonly property bool lowBattery: percent < settings.v["power.saverBelow"]
    readonly property string autoProfile: !ready ? "" : !onBattery ? "balanced" : batteryMode === "saver" ? "saver" : batteryMode === "boost" ? (busy ? "balanced" : "saver") : (lowBattery ? "saver" : "balanced")
    // The last automatic choice, and whether a profile picked by hand holds
    // it off (until the next plug or unplug).
    property string lastAuto: ""
    property bool handPicked: false
    property int setByUs: -1

    onAutoProfileChanged: Qt.callLater(applyAuto)
    onOnBatteryChanged: {
        handPicked = false;
        Qt.callLater(applyAuto);
    }

    Connections {
        target: PowerProfiles

        function onProfileChanged(): void {
            if (root.setByUs >= 0 && PowerProfiles.profile !== root.setByUs)
                root.handPicked = true;
        }
    }

    function applyAuto(): void {
        if (!autoProfile || autoProfile === lastAuto || handPicked)
            return;
        const before = lastAuto;
        lastAuto = autoProfile;
        setByUs = autoProfile === "saver" ? PowerProfile.PowerSaver : PowerProfile.Balanced;
        PowerProfiles.profile = setByUs;
        // Only the low-battery switch says so; boosts come and go quietly.
        if (batteryMode === "balanced" && onBattery && autoProfile === "saver")
            notify("normal", "battery-low", "Battery saver turned on", `Battery at ${percent}%. Plug in to go back to Balanced.`);
        else if (batteryMode === "balanced" && before === "saver" && !onBattery)
            notify("normal", "battery-good-charging", "Battery saver turned off", "Back to Balanced.");
    }

    // ── Busy (boost) ──
    // The CPU's share in use, every 5 s from /proc/stat while on battery in
    // boost mode: busy after 15 s above 35% (about four of its twelve
    // threads), quiet again after a minute under 15%.
    property bool busy: false
    property real load: 0
    property var _prev: null
    property int _hot: 0
    property int _cold: 0

    Timer {
        running: root.onBattery && root.batteryMode === "boost"
        interval: 5000
        repeat: true
        triggeredOnStart: true
        onRunningChanged: {
            if (!running) {
                root.busy = false;
                root._prev = null;
                root._hot = root._cold = 0;
            }
        }
        onTriggered: stat.reload()
    }

    FileView {
        id: stat

        path: "/proc/stat"
        blockLoading: true
        onLoaded: {
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + f[4];
            const total = f.reduce((a, b) => a + b, 0);
            if (root._prev) {
                const dt = total - root._prev.total;
                root.load = dt > 0 ? 1 - (idle - root._prev.idle) / dt : 0;
                root._hot = root.load > 0.35 ? root._hot + 1 : 0;
                root._cold = root.load < 0.15 ? root._cold + 1 : 0;
                if (!root.busy && root._hot >= 3)
                    root.busy = true;
                else if (root.busy && root._cold >= 12)
                    root.busy = false;
            }
            root._prev = {
                idle,
                total
            };
        }
    }

    // ── Warnings ──
    property int lastPercent: -1

    onPercentChanged: {
        const before = lastPercent;
        lastPercent = percent;
        if (!ready || charging || before < 0)
            return;
        const critical = settings.v["power.warnCritical"];
        const lowAt = settings.v["power.warnLow"];
        if (critical > 0 && before >= critical && percent < critical)
            notify("critical", "battery-caution", "Battery critically low", `${percent}% left. Plug in now.`);
        else if (lowAt > 0 && before >= lowAt && percent < lowAt)
            notify("normal", "battery-low", "Battery low", `${percent}% left. Plug in soon.`);
    }

    function notify(urgency: string, icon: string, title: string, body: string): void {
        Quickshell.execDetached(["notify-send", "--app-name=Power", "-u", urgency, "-i", icon, title, body]);
    }
}
