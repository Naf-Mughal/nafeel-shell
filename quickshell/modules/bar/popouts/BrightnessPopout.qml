import QtQuick
import qs.config
import qs.services
import qs.components

// Display: screen brightness, then night light, caffeine and dark mode as
// expressive tiles.
Panel {
    id: root

    gloss: Xian.gloss.display
    icon: "light_mode"
    title: "Display"
    subtitle: `Brightness ${Math.round(Brightness.level * 100)}%`


    StyledSlider {
        width: parent.width
        icon: "brightness_6"
        value: Brightness.level
        onMoved: v => Brightness.set(v)
    }

    Grid {
        width: parent.width
        columns: 2
        spacing: Tokens.spacing.small

        Tile {
            width: (root.width - Tokens.spacing.small) / 2
            icon: "nightlight"
            label: "Night light"
            sublabel: Display.nightLight ? "On" : "Off"
            checked: Display.nightLight
            onClicked: Display.toggleNightLight()
        }

        Tile {
            width: (root.width - Tokens.spacing.small) / 2
            icon: "coffee"
            label: "Caffeine"
            sublabel: Display.caffeine ? "Awake" : "Off"
            checked: Display.caffeine
            onClicked: Display.toggleCaffeine()
        }

        Tile {
            width: (root.width - Tokens.spacing.small) / 2
            icon: "dark_mode"
            label: "Dark mode"
            sublabel: Colours.light ? "Off" : "On"
            checked: !Colours.light
            onClicked: Display.toggleDarkMode()
        }
    }
}
