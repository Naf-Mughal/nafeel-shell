pragma Singleton

// Battery and power profile, live from UPower, and the battery's care (from
// idle-kit's power-mode and battery-warn, as shell code):
//
//   battery saver  on battery below the saver level the power profile goes
//                  to Power Saver; plugging in (or charging back above it)
//                  returns it to Balanced. It only acts when that automatic
//                  choice changes, so a profile you pick yourself stays until
//                  the next plug, unplug or crossing.
//   warnings       a notification once when the battery falls below the low
//                  level, and a critical one below the critical level.
//
// Their levels are the battery part of the Settings panel's Power & idle page.

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.config

Singleton {
    id: root

    readonly property SettingsPage settings: SettingsPage {
        name: "power"
        order: 36

        SettingItem {
            key: "power.saverBelow"
            kind: "number"
            section: "Battery"
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

    // ── Battery saver ──
    readonly property string autoProfile: ready && !charging && percent < settings.v["power.saverBelow"] ? "saver" : "balanced"
    // The last automatic choice ("" until the battery is first read).
    property string lastAuto: ""

    onAutoProfileChanged: Qt.callLater(applyAuto)
    onReadyChanged: Qt.callLater(applyAuto)

    function applyAuto(): void {
        if (!ready || autoProfile === lastAuto)
            return;
        const before = lastAuto;
        lastAuto = autoProfile;
        // At start only a low battery acts: a restart doesn't undo a profile
        // picked by hand.
        if (before === "" && autoProfile !== "saver")
            return;
        PowerProfiles.profile = autoProfile === "saver" ? PowerProfile.PowerSaver : PowerProfile.Balanced;
        if (autoProfile === "saver")
            notify("normal", "battery-low", "Battery saver turned on", `Battery at ${percent}%. Plug in to go back to Balanced.`);
        else if (before === "saver")
            notify("normal", "battery-good-charging", "Battery saver turned off", "Back to Balanced.");
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
