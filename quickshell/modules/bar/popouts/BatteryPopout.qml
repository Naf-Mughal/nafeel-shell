import QtQuick
import Quickshell.Services.UPower
import qs.config
import qs.services
import qs.components

// Battery: a big charge hero (level bar, state, time left), the power
// profile as a connected button group, and health facts from UPower.
Panel {
    id: root

    function duration(s: real): string {
        if (s <= 0)
            return "";
        const h = Math.floor(s / 3600), m = Math.round((s % 3600) / 60);
        return h > 0 ? `${h} h ${m} min` : `${m} min`;
    }

    spacing: Tokens.spacing.normal

    Surface {
        id: hero

        width: parent.width
        height: 112
        shape: "large"
        role: Power.low ? "error" : "primary"

        Column {
            anchors.fill: parent
            anchors.margins: Tokens.spacing.large
            spacing: Tokens.spacing.small

            Row {
                spacing: Tokens.spacing.small

                StyledText {
                    text: `${Math.round(Power.level * 100)}%`
                    color: hero.ink
                    font.family: Tokens.font.serif
                    font.pixelSize: 36
                    font.weight: Font.DemiBold
                }

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Power.charging
                    text: "bolt"
                    fill: 1
                    size: 26
                    color: hero.ink
                }
            }

            StyledRect {
                width: parent.width
                height: 8
                radius: 4
                color: Qt.alpha(hero.ink, 0.25)

                StyledRect {
                    width: parent.width * Power.level
                    height: parent.height
                    radius: 4
                    color: hero.ink
                }
            }

            StyledText {
                text: Power.charging ? (Power.timeToFull > 0 ? `Charging · full in ${root.duration(Power.timeToFull)}` : "Charging") : (Power.timeToEmpty > 0 ? `On battery · ${root.duration(Power.timeToEmpty)} left` : "On battery")
                color: Qt.alpha(hero.ink, 0.85)
                font.pixelSize: 12
            }
        }
    }

    SectionLabel {
        text: "Power profile"
    }

    ButtonGroup {
        width: parent.width
        current: PowerProfiles.profile
        model: [
            {
                value: PowerProfile.PowerSaver,
                icon: "eco",
                label: "Saver"
            },
            {
                value: PowerProfile.Balanced,
                icon: "balance",
                label: "Balanced"
            },
            ...(PowerProfiles.hasPerformanceProfile ? [
                    {
                        value: PowerProfile.Performance,
                        icon: "speed",
                        label: "Performance"
                    }
                ] : [])
        ]
        onSelected: v => PowerProfiles.profile = v
    }

    SectionLabel {
        text: "Health"
    }

    Grid {
        width: parent.width
        columns: 3
        spacing: Tokens.spacing.small

        Fact {
            label: "Health"
            value: Power.battery?.healthSupported ? `${Math.round(Power.battery.healthPercentage)}%` : "—"
        }
        Fact {
            label: "Capacity"
            value: Power.battery ? `${Power.battery.energyCapacity.toFixed(1)} Wh` : "—"
        }
        Fact {
            label: Power.charging ? "Charging at" : "Drawing"
            value: Power.battery ? `${Math.abs(Power.battery.changeRate).toFixed(1)} W` : "—"
        }
    }

    component Fact: Surface {
        id: fact

        property string label
        property string value

        width: (root.width - Tokens.spacing.small * 2) / 3
        height: 56

        Column {
            anchors.centerIn: parent

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: fact.value
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: fact.label
                color: Colours.palette.m3onSurfaceVariant
                font.pixelSize: 11
            }
        }
    }
}
