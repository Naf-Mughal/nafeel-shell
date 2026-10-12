pragma Singleton
pragma ComponentBehavior: Bound

// The shell's colours: every Material 3 role, as Caelestia's Colours service
// (caelestia-dots/shell, GPL-3.0) exposes them: `palette.m3<role>` solid, and
// `tPalette.m3<role>` with the transparency layering applied.
//
// From the theme's token document (theme.json, made by bin/nafeel-theme):
// every role for dark and light, the terminal colours, and the shell's own
// tokens (paper levels, ink, the wallpaper's pigments). The app templates
// render from the same document. Theme calls load(doc): under the ink
// transition when the wallpaper changes, at once otherwise; nothing here
// watches the file, so colours never change outside that choreography.
//
// Colours animate where they're drawn (StyledRect, StyledText, the frame): a
// Behavior inside a singleton crashes Quickshell.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/nafeel-shell"

    property bool light
    readonly property M3Palette palette: M3Palette {}
    readonly property M3TPalette tPalette: M3TPalette {}
    readonly property Transparency transparency: Transparency {}

    // theme.json as read.
    property var theme: null

    function getLuminance(c: color): real {
        if (c.r == 0 && c.g == 0 && c.b == 0)
            return 0;
        return Math.sqrt(0.299 * (c.r ** 2) + 0.587 * (c.g ** 2) + 0.114 * (c.b ** 2));
    }

    // A surface layer `layer` steps above the base, lighter in dark mode.
    function alterColour(c: color, a: real, layer: int): color {
        const luminance = getLuminance(c);
        if (luminance === 0)
            return Qt.rgba(c.r, c.g, c.b, a);
        const offset = (!light || layer == 1 ? 1 : -layer / 2) * (light ? 0.2 : 0.3) * (1 - transparency.base);
        const scale = (luminance + offset) / luminance;
        return Qt.rgba(Math.max(0, Math.min(1, c.r * scale)), Math.max(0, Math.min(1, c.g * scale)), Math.max(0, Math.min(1, c.b * scale)), a);
    }

    function layer(c: color, layer: var): color {
        if (!transparency.enabled)
            return c;
        return layer === 0 ? Qt.alpha(c, transparency.base) : alterColour(c, transparency.layers, layer ?? 1);
    }

    // ── Roles ─────────────────────────────────────────────────────────────
    // What a surface is made of, by name rather than by colour, so every
    // component pairs fill and ink the same way:
    //   role      "paper" (the sheet) | "primary" | "secondary" | "tertiary" | "error"
    //   emphasis  "soft" (its container) | "strong" (filled) | "ghost" (no fill)
    //   level     paper only: 0 lowest .. 4 highest
    readonly property var paperLevels: ["surfaceContainerLowest", "surfaceContainerLow", "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest"]

    function cap(s: string): string {
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    function roleFill(role: string, emphasis: string, level: int): color {
        if (emphasis === "ghost")
            return "transparent";
        if (role === "paper")
            return palette[`m3${paperLevels[Math.max(0, Math.min(4, level))]}`];
        return palette[emphasis === "strong" ? `m3${role}` : `m3${role}Container`];
    }

    function roleInk(role: string, emphasis: string): color {
        if (role === "paper")
            return palette.m3onSurface;
        if (emphasis === "ghost")
            return palette[`m3${role}`];
        return palette[emphasis === "strong" ? `m3on${cap(role)}` : `m3on${cap(role)}Container`];
    }

    // Secondary text on a role: paper's own variant ink, else the ink, softer.
    function roleSubInk(role: string, emphasis: string): color {
        return role === "paper" ? palette.m3onSurfaceVariant : Qt.alpha(roleInk(role, emphasis), 0.8);
    }

    // A readable text colour on `c`.
    function on(c: color): color {
        if (c.hslLightness < 0.5)
            return Qt.hsla(c.hslHue, c.hslSaturation, 0.9, 1);
        return Qt.hsla(c.hslHue, c.hslSaturation, 0.1, 1);
    }

    readonly property var ansi: ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]

    function load(doc: var): void {
        theme = doc;
        apply();
    }

    // theme.json's tokens for its mode onto the palette: snake_case roles to
    // m3camelCase, terminal_normal/bright_* to term0-15.
    function apply(): void {
        const t = theme;
        if (!t?.dark)
            return;
        light = t.mode === "light";
        const tokens = t[light ? "light" : "dark"];
        const camel = s => s.replace(/_([a-z])/g, (_, c) => c.toUpperCase());
        for (const [name, colour] of Object.entries(tokens)) {
            if (!/^#[0-9a-fA-F]{6}$/.test(colour))
                continue;
            const prop = `m3${camel(name)}`;
            if (palette.hasOwnProperty(prop))
                palette[prop] = colour;
        }
        ansi.forEach((name, i) => {
            palette[`term${i}`] = tokens[`terminal_normal_${name}`] ?? palette[`term${i}`];
            palette[`term${i + 8}`] = tokens[`terminal_bright_${name}`] ?? palette[`term${i + 8}`];
        });
    }

    component Transparency: QtObject {
        readonly property bool enabled: Tokens.transparency.enabled
        readonly property real base: Math.max(0, Math.min(1, Tokens.transparency.base - (root.light ? 0.1 : 0)))
        readonly property real layers: Math.max(0, Math.min(1, Tokens.transparency.layers))
    }

    component M3TPalette: QtObject {
        readonly property color m3background: root.layer(root.palette.m3background, 0)
        readonly property color m3onBackground: root.palette.m3onBackground
        readonly property color m3surface: root.layer(root.palette.m3surface, 0)
        readonly property color m3surfaceDim: root.layer(root.palette.m3surfaceDim, 0)
        readonly property color m3surfaceBright: root.layer(root.palette.m3surfaceBright, 0)
        readonly property color m3surfaceContainerLowest: root.layer(root.palette.m3surfaceContainerLowest)
        readonly property color m3surfaceContainerLow: root.layer(root.palette.m3surfaceContainerLow)
        readonly property color m3surfaceContainer: root.layer(root.palette.m3surfaceContainer)
        readonly property color m3surfaceContainerHigh: root.layer(root.palette.m3surfaceContainerHigh)
        readonly property color m3surfaceContainerHighest: root.layer(root.palette.m3surfaceContainerHighest)
        readonly property color m3onSurface: root.palette.m3onSurface
        readonly property color m3surfaceVariant: root.layer(root.palette.m3surfaceVariant, 0)
        readonly property color m3onSurfaceVariant: root.palette.m3onSurfaceVariant
        readonly property color m3inverseSurface: root.layer(root.palette.m3inverseSurface, 0)
        readonly property color m3inverseOnSurface: root.palette.m3inverseOnSurface
        readonly property color m3outline: root.palette.m3outline
        readonly property color m3outlineVariant: root.palette.m3outlineVariant
        readonly property color m3shadow: root.palette.m3shadow
        readonly property color m3scrim: root.palette.m3scrim
    }

    component M3Palette: QtObject {
        property color m3background: "#191114"
        property color m3onBackground: "#efdfe2"
        property color m3surface: "#191114"
        property color m3surfaceDim: "#191114"
        property color m3surfaceBright: "#403739"
        property color m3surfaceContainerLowest: "#130c0e"
        property color m3surfaceContainerLow: "#22191c"
        property color m3surfaceContainer: "#261d20"
        property color m3surfaceContainerHigh: "#31282a"
        property color m3surfaceContainerHighest: "#3c3235"
        property color m3onSurface: "#efdfe2"
        property color m3surfaceVariant: "#514347"
        property color m3onSurfaceVariant: "#d5c2c6"
        property color m3inverseSurface: "#efdfe2"
        property color m3inverseOnSurface: "#372e30"
        property color m3outline: "#9e8c90"
        property color m3outlineVariant: "#514347"
        property color m3shadow: "#000000"
        property color m3scrim: "#000000"
        property color m3surfaceTint: "#ffb0ca"
        property color m3primary: "#ffb0ca"
        property color m3onPrimary: "#541d34"
        property color m3primaryContainer: "#6f334a"
        property color m3onPrimaryContainer: "#ffd9e3"
        property color m3inversePrimary: "#8b4a62"
        property color m3secondary: "#e2bdc7"
        property color m3onSecondary: "#422932"
        property color m3secondaryContainer: "#5a3f48"
        property color m3onSecondaryContainer: "#ffd9e3"
        property color m3tertiary: "#f0bc95"
        property color m3onTertiary: "#48290c"
        property color m3tertiaryContainer: "#b58763"
        property color m3onTertiaryContainer: "#000000"
        property color m3error: "#ffb4ab"
        property color m3onError: "#690005"
        property color m3errorContainer: "#93000a"
        property color m3onErrorContainer: "#ffdad6"
        property color m3primaryFixed: "#ffd9e3"
        property color m3primaryFixedDim: "#ffb0ca"
        property color m3onPrimaryFixed: "#39071f"
        property color m3onPrimaryFixedVariant: "#6f334a"
        property color m3secondaryFixed: "#ffd9e3"
        property color m3secondaryFixedDim: "#e2bdc7"
        property color m3onSecondaryFixed: "#2b151d"
        property color m3onSecondaryFixedVariant: "#5a3f48"
        property color m3tertiaryFixed: "#ffdcc3"
        property color m3tertiaryFixedDim: "#f0bc95"
        property color m3onTertiaryFixed: "#2f1500"
        property color m3onTertiaryFixedVariant: "#623f21"
        property color term0: "#353434"
        property color term1: "#ff4c8a"
        property color term2: "#ffbbb7"
        property color term3: "#ffdedf"
        property color term4: "#b3a2d5"
        property color term5: "#e491bd"
        property color term6: "#ffba93"
        property color term7: "#eed1d2"
        property color term8: "#b39e9e"
        property color term9: "#ff80a3"
        property color term10: "#ffd3d0"
        property color term11: "#fff1f0"
        property color term12: "#dcbc93"
        property color term13: "#f9a8c6"
        property color term14: "#ffd1c0"
        property color term15: "#ffffff"
    }
}
