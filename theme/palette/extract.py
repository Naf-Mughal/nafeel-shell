#!/usr/bin/env python3
"""Wallpaper palette extractor for the nafeel/wallpaper-palette plugin.

A port of Caelestia's dynamic scheme (caelestia-cli, GPL-3.0:
src/caelestia/utils/material/{score,generator}.py, utils/colourfulness.py and
the smart options in utils/wallpaper.py), writing a Noctalia custom palette
instead of Caelestia's scheme.json:

  1. a 128px thumbnail of the wallpaper (nearest neighbour, saved as JPEG,
     exactly as Caelestia makes it)
  2. Celebi quantization to 128 colours, then Caelestia's own Score: hue
     proportion vs chroma, then the first colour above a falling chroma/tone
     cutoff, then the dislike fix. That's the seed.
  3. the Material You scheme for the chosen variant (materialyoucolor, the
     same library and spec Caelestia uses), plus Caelestia's harmonized
     gruvbox terminal colours and its "hard" flavour
  4. mapped to Noctalia's 16 roles the way Noctalia maps its own m3-*
     schemes, with both dark and light written

    extract.py IMAGE [OUT.json] [--variant auto|tonalspot|...] [--flavour default|hard]
                                [--contrast -1..1] [--cache DIR] [--scheme-out SCHEME.json]

--scheme-out also writes the whole scheme, every Material role (Caelestia's
camelCase names, "#rrggbb") plus term0-15 for dark and light, for the
nafeel/shell Quickshell shell, which needs more than Noctalia's 16 roles.

"auto" picks the variant like Caelestia's smart scheme (neutral / content /
tonalspot by how colourful the wallpaper is). Prints one JSON line on
stdout: {seed, variant, mode, primary, secondary, tertiary}, where "mode" is
the light/dark Caelestia's smart scheme would pick. With no OUT the palette
is printed instead. Needs materialyoucolor and pillow (the plugin keeps them
in a venv), and ffmpeg for video wallpapers.
"""

import argparse
import hashlib
import json
import os
import subprocess
import sys
import tempfile

from materialyoucolor.blend import Blend
from materialyoucolor.dislike.dislike_analyzer import DislikeAnalyzer
from materialyoucolor.dynamiccolor.material_dynamic_colors import MaterialDynamicColors
from materialyoucolor.hct import Hct
from materialyoucolor.quantize import ImageQuantizeCelebi
from materialyoucolor.scheme.scheme_content import SchemeContent
from materialyoucolor.scheme.scheme_expressive import SchemeExpressive
from materialyoucolor.scheme.scheme_fidelity import SchemeFidelity
from materialyoucolor.scheme.scheme_fruit_salad import SchemeFruitSalad
from materialyoucolor.scheme.scheme_monochrome import SchemeMonochrome
from materialyoucolor.scheme.scheme_neutral import SchemeNeutral
from materialyoucolor.scheme.scheme_rainbow import SchemeRainbow
from materialyoucolor.scheme.scheme_tonal_spot import SchemeTonalSpot
from materialyoucolor.scheme.scheme_vibrant import SchemeVibrant
from materialyoucolor.utils.color_utils import argb_from_rgb
from materialyoucolor.utils.math_utils import (
    difference_degrees,
    rotation_direction,
    sanitize_degrees_double,
    sanitize_degrees_int,
)
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pigment  # noqa: E402  (bin/pigment.py: the ink-and-paper palette)

SCHEMES = {
    "tonalspot": SchemeTonalSpot,
    "vibrant": SchemeVibrant,
    "expressive": SchemeExpressive,
    "fidelity": SchemeFidelity,
    "content": SchemeContent,
    "fruitsalad": SchemeFruitSalad,
    "rainbow": SchemeRainbow,
    "neutral": SchemeNeutral,
    "monochrome": SchemeMonochrome,
}
# The pigment palette's styles (bin/pigment.py STYLES), as variants.
PIGMENTS = {
    "pigment": "faithful",
    "pigment-vibrant": "vibrant",
    "pigment-expressive": "expressive",
    "pigment-fruitsalad": "fruitsalad",
    "pigment-soft": "soft",
}
VIDEO = (".mp4", ".webm", ".mkv", ".mov", ".avi", ".m4v", ".gif")


# ── Seed: Caelestia's Score (material/score.py) ─────────────────────────
class Score:
    TARGET_CHROMA = 48.0
    WEIGHT_PROPORTION = 0.7
    WEIGHT_CHROMA_ABOVE = 0.3
    WEIGHT_CHROMA_BELOW = 0.1
    CUTOFF_CHROMA = 5.0
    CUTOFF_EXCITED_PROPORTION = 0.01

    @staticmethod
    def score(colors_to_population: dict, filter_enabled: bool = False) -> Hct:
        colors_hct = []
        hue_population = [0] * 360
        population_sum = 0

        for rgb, population in colors_to_population.items():
            hct = Hct.from_int(rgb)
            colors_hct.append(hct)
            hue = int(hct.hue)
            hue_population[hue] += population
            population_sum += population

        hue_excited_proportions = [0.0] * 360

        for hue in range(360):
            proportion = hue_population[hue] / population_sum
            for i in range(hue - 14, hue + 16):
                neighbor_hue = int(sanitize_degrees_int(i))
                hue_excited_proportions[neighbor_hue] += proportion

        scored_hct = []
        for hct in colors_hct:
            hue = int(sanitize_degrees_int(round(hct.hue)))
            proportion = hue_excited_proportions[hue]

            if filter_enabled and (hct.chroma < Score.CUTOFF_CHROMA or proportion <= Score.CUTOFF_EXCITED_PROPORTION):
                continue

            proportion_score = proportion * 100.0 * Score.WEIGHT_PROPORTION
            chroma_weight = Score.WEIGHT_CHROMA_BELOW if hct.chroma < Score.TARGET_CHROMA else Score.WEIGHT_CHROMA_ABOVE
            chroma_score = (hct.chroma - Score.TARGET_CHROMA) * chroma_weight
            scored_hct.append({"hct": hct, "score": proportion_score + chroma_score})

        scored_hct.sort(key=lambda x: x["score"], reverse=True)

        primary = None
        for cutoff in range(20, -1, -1):
            for item in scored_hct:
                if item["hct"].chroma > cutoff and item["hct"].tone > cutoff * 3:
                    primary = item["hct"]
                    break
            if primary:
                break

        return DislikeAnalyzer.fix_if_disliked(primary) if primary else Score.score(colors_to_population, False)


# ── Smart options: Caelestia's colourfulness.py + get_smart_opts ─────────
def colourfulness(image: Image.Image) -> float:
    rg, yb = [], []
    # getdata() is what Caelestia uses; Pillow 14 removes it for get_flattened_data().
    pixels = image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata()
    for r, g, b in pixels:
        rg.append(abs(r - g))
        yb.append(abs(0.5 * (r + g) - b))

    def mean(v):
        return sum(v) / len(v) if v else 0

    def std(v, m):
        return (sum((x - m) ** 2 for x in v) / len(v)) ** 0.5 if v else 0

    mrg, myb = mean(rg), mean(yb)
    return (std(rg, mrg) ** 2 + std(yb, myb) ** 2) ** 0.5 + 0.3 * (mrg**2 + myb**2) ** 0.5


def smart_options(thumb: str) -> dict:
    with Image.open(thumb) as img:
        c = colourfulness(img)
        variant = "neutral" if c < 10 else "content" if c < 20 else "tonalspot"
        img.thumbnail((1, 1), Image.Resampling.LANCZOS)
        pixel = img.getpixel((0, 0))
        mode = "light" if Hct.from_int(argb_from_rgb(*pixel[:3])).tone > 60 else "dark"
    return {"variant": variant, "mode": mode}


# ── Scheme: Caelestia's material/generator.py ───────────────────────────
def hex_to_hct(h: str) -> Hct:
    return Hct.from_int(int(f"0xFF{h}", 16))


light_gruvbox = [hex_to_hct(h) for h in (
    "FDF9F3", "FF6188", "A9DC76", "FC9867", "FFD866", "F47FD4", "78DCE8", "333034",
    "121212", "FF6188", "A9DC76", "FC9867", "FFD866", "F47FD4", "78DCE8", "333034",
)]
dark_gruvbox = [hex_to_hct(h) for h in (
    "282828", "CC241D", "98971A", "D79921", "458588", "B16286", "689D6A", "A89984",
    "928374", "FB4934", "B8BB26", "FABD2F", "83A598", "D3869B", "8EC07C", "EBDBB2",
)]


def lighten(c: Hct, amount: float) -> Hct:
    diff = (100 - c.tone) * amount
    return Hct.from_hct(c.hue, c.chroma + diff / 5, c.tone + diff)


def darken(c: Hct, amount: float) -> Hct:
    diff = c.tone * amount
    return Hct.from_hct(c.hue, c.chroma - diff / 5, c.tone - diff)


def grayscale(c: Hct, light: bool) -> Hct:
    c = darken(c, 0.35) if light else lighten(c, 0.65)
    c.chroma = 0
    return c


def harmonize(from_hct: Hct, to_hct: Hct, tone_boost: float) -> Hct:
    rotation = min(difference_degrees(from_hct.hue, to_hct.hue) * 0.8, 100)
    hue = sanitize_degrees_double(from_hct.hue + rotation * rotation_direction(from_hct.hue, to_hct.hue))
    return Hct.from_hct(hue, from_hct.chroma, from_hct.tone * (1 + tone_boost))


def gen_scheme(seed: Hct, variant: str, flavour: str, light: bool, contrast: float) -> dict[str, Hct]:
    """The Material and terminal colours of Caelestia's scheme.json (its
    catppuccin / KDE / deprecated extras are left out: Noctalia has no use for them)."""
    scheme = SCHEMES[variant](source_color_hct=seed, is_dark=not light, contrast_level=contrast)
    colours = {c.name: c.get_hct(scheme) for c in MaterialDynamicColors().all_colors}
    key = colours["primaryPaletteKeyColor"]

    for i, hct in enumerate(light_gruvbox if light else dark_gruvbox):
        if variant == "monochrome":
            colours[f"term{i}"] = grayscale(hct, light)
        else:
            colours[f"term{i}"] = harmonize(hct, key, (0.35 if i < 8 else 0.2) * (-1 if light else 1))

    if variant == "neutral":
        for c in colours.values():
            c.chroma -= 15

    if flavour == "hard":
        for name in "background", *(k for k in colours if k.startswith("surface")):
            colours[name] = lighten(colours[name], 0.4) if light else darken(colours[name], 0.8)
        colours["term0"] = lighten(colours["term0"], 0.4) if light else darken(colours["term0"], 0.9)

    return colours


# ── Noctalia palette ───────────────────────────────────────────────────
def hx(c: Hct) -> str:
    return "#%06x" % (c.to_int() & 0xFFFFFF)


ANSI = ("black", "red", "green", "yellow", "blue", "magenta", "cyan", "white")


def to_noctalia(c: dict[str, Hct]) -> dict:
    """Roles as Noctalia maps its own M3 schemes (theme/fixed_palette.cpp
    mapGeneratedPaletteMode + setGeneratedHoverTokens); terminal as Caelestia
    sends it to terminals (utils/theme.py gen_sequences)."""
    return {
        "mPrimary": hx(c["primary"]),
        "mOnPrimary": hx(c["onPrimary"]),
        "mSecondary": hx(c["secondary"]),
        "mOnSecondary": hx(c["onSecondary"]),
        "mTertiary": hx(c["tertiary"]),
        "mOnTertiary": hx(c["onTertiary"]),
        "mError": hx(c["error"]),
        "mOnError": hx(c["onError"]),
        "mSurface": hx(c["surface"]),
        "mOnSurface": hx(c["onSurface"]),
        "mSurfaceVariant": hx(c["surfaceContainer"]),
        "mOnSurfaceVariant": hx(c["onSurfaceVariant"]),
        "mOutline": hx(c["outlineVariant"]),
        "mShadow": hx(c["shadow"]),
        "mHover": hx(c["tertiary"]),
        "mOnHover": hx(c["onTertiary"]),
        "terminal": {
            "foreground": hx(c["onSurface"]),
            "background": hx(c["surface"]),
            "cursor": hx(c["secondary"]),
            "cursorText": hx(c["onSecondary"]),
            "selectionBg": hx(c["secondary"]),
            "selectionFg": hx(c["onSecondary"]),
            "normal": {name: hx(c[f"term{i}"]) for i, name in enumerate(ANSI)},
            "bright": {name: hx(c[f"term{i + 8}"]) for i, name in enumerate(ANSI)},
        },
    }


# ── Wallpaper → thumbnail → seed (cached per file, like Caelestia) ───────
def file_hash(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def thumbnail(path: str, cache: str) -> str:
    thumb = os.path.join(cache, "thumbnail.jpg")
    if os.path.exists(thumb):
        return thumb
    source = path
    if path.lower().endswith(VIDEO):
        # A video wallpaper (mpvpaper): a frame from its first second.
        source = os.path.join(cache, "frame.png")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-ss", "1", "-i", path, "-frames:v", "1", source],
                       check=True)
    with Image.open(source) as img:
        img = img.convert("RGB")
        img.thumbnail((128, 128), Image.Resampling.NEAREST)
        img.save(thumb, "JPEG")
    return thumb


def cached_json(path: str, make):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        pass
    value = make()
    with open(path, "w") as f:
        json.dump(value, f)
    return value


def write_json(path: str, value) -> None:
    """Write `value` to `path` whole (to a temp file, then rename)."""
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(value, f, indent=2)
    os.replace(tmp, path)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("image")
    ap.add_argument("out", nargs="?")
    ap.add_argument("--variant", default="pigment", choices=[*PIGMENTS, "auto", *SCHEMES])
    ap.add_argument("--flavour", default="default", choices=["default", "hard"])
    ap.add_argument("--contrast", type=float, default=0.0)
    ap.add_argument("--cache", default=os.path.join(tempfile.gettempdir(), "wallpaper-palette"))
    ap.add_argument("--scheme-out")
    args = ap.parse_args()

    if not os.path.exists(args.image):
        sys.exit(f"no such wallpaper: {args.image}")
    contrast = max(-1.0, min(1.0, args.contrast))

    cache = os.path.join(args.cache, file_hash(args.image))
    os.makedirs(cache, exist_ok=True)
    thumb = thumbnail(args.image, cache)
    smart = cached_json(os.path.join(cache, "smart.json"), lambda: smart_options(thumb))
    variant = smart["variant"] if args.variant == "auto" else args.variant

    if variant in PIGMENTS:
        # The whole wallpaper, weighed by coverage and intensity (pigment.py).
        schemes, reading = {}, None
        for mode in ("dark", "light"):
            # The full image (or a video's frame): pigment averages it down
            # itself, in Oklab.
            source = os.path.join(cache, "frame.png") if args.image.lower().endswith(VIDEO) else args.image
            schemes[mode], reading = pigment.generate(source, mode == "light", contrast, PIGMENTS[variant])
        seed = schemes["dark"]["primaryPaletteKeyColor"]
    else:
        seed = Hct.from_int(cached_json(os.path.join(cache, "score.json"),
                                        lambda: Score.score(ImageQuantizeCelebi(thumb, 1, 128)).to_int()))
        schemes = {mode: gen_scheme(seed, variant, args.flavour, mode == "light", contrast) for mode in ("dark", "light")}
        reading = None
    palette = {mode: to_noctalia(c) for mode, c in schemes.items()}
    d = palette["dark"]
    summary = {
        "seed": hx(seed), "variant": variant, "mode": smart["mode"],
        "primary": d["mPrimary"], "secondary": d["mSecondary"], "tertiary": d["mTertiary"],
    }

    if args.scheme_out:
        write_json(args.scheme_out, {
            "variant": variant, "flavour": args.flavour, "seed": hx(seed),
            **({"pigment": reading} if reading else {}),
            **{mode: {name: hx(c) for name, c in colours.items()} for mode, colours in schemes.items()},
        })
    if not args.out:
        print(json.dumps({"summary": summary, **palette}, indent=2))
        return
    write_json(args.out, palette)
    print(json.dumps(summary))


if __name__ == "__main__":
    main()
