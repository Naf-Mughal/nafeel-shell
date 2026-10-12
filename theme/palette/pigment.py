"""Pigment: a wallpaper palette for ink and paper.

Material You builds every role from one seed colour. Pigment reads the whole
wallpaper and uses its colours as they are:

  surfaces  black and white: the wallpaper's own ink (dark) and paper
            (light), barely tinted. The paper look comes from the shell's
            frosted translucency, not from coloured surfaces.
  accents   the wallpaper's real colours, each weighed by how much of the
            picture it covers and how vivid it is: the most covering leads
            (primary), the most vivid of the rest pops (tertiary), the next
            real colour is secondary. A colour that isn't in the picture is
            never invented (only the fruit-salad style blends), and a
            black-and-white wallpaper gives a black-and-white palette.

Reading the image (after Okmain, dgroshev.com/blog/okmain):

  1. Average down in Oklab (not sRGB, which turns muddy) to about 96 px
     wide, so noise like paper grain or cracks never forms a colour of its
     own.
  2. Weigh each pixel by its place: the centre of the picture counts fully,
     falling off toward the borders.
  3. Split neutrals (chroma under NEUTRAL_C: the ink and paper) from colour.
  4. Cluster the colour pixels with weighted k-means++ in Oklab's a/b plane
     (hue and chroma together, so a vivid red and a soft ochre stay apart),
     then merge clusters that are really one colour.

Writes the Material role names (and term0-15), so the shell, Noctalia and the
app templates take it unchanged.
"""

import math

from materialyoucolor.hct import Hct
from PIL import Image

# ── Oklab ─────────────────────────────────────────────────────────────────


def _lin(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _gam(c: float) -> float:
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


_LIN = [_lin(i / 255) for i in range(256)]


def lin_to_oklab(r: float, g: float, b: float) -> tuple[float, float, float]:
    l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ** (1 / 3)
    m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ** (1 / 3)
    s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ** (1 / 3)
    return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


def rgb_to_oklab(r: int, g: int, b: int) -> tuple[float, float, float]:
    return lin_to_oklab(_LIN[r], _LIN[g], _LIN[b])


def oklab_to_linear(L: float, a: float, b: float) -> tuple[float, float, float]:
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    return (4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)


def _in_gamut(L: float, C: float, h: float) -> bool:
    rgb = oklab_to_linear(L, C * math.cos(math.radians(h)), C * math.sin(math.radians(h)))
    return all(-1e-4 <= c <= 1 + 1e-4 for c in rgb)


def oklch(L: float, C: float, h: float) -> int:
    """An OKLCH colour as ARGB, chroma reduced until it fits sRGB."""
    if not _in_gamut(L, C, h):
        lo, hi = 0.0, C
        for _ in range(20):
            mid = (lo + hi) / 2
            lo, hi = (mid, hi) if _in_gamut(L, mid, h) else (lo, mid)
        C = lo
    rgb = oklab_to_linear(L, C * math.cos(math.radians(h)), C * math.sin(math.radians(h)))
    r, g, b = (max(0, min(255, round(_gam(max(0.0, min(1.0, c))) * 255))) for c in rgb)
    return 0xFF000000 | (r << 16) | (g << 8) | b


def hue_diff(a: float, b: float) -> float:
    d = abs(a - b) % 360
    return min(d, 360 - d)


def keep_name(h: float, L: float) -> float:
    """A warm hue made lighter keeps its colour's name: an ochre lightened is
    a yellow (not peach), an orange an apricot and a red a coral (not pink).
    Darker tones keep their hue (a dark yellow is a brown, which is right)."""
    h %= 360
    if L <= 0.6:
        return h
    t = min(1.0, (L - 0.6) / 0.35)
    if 50 <= h <= 110:      # yellows and ochres -> yellow
        return h + (102 - h) * 0.85 * t
    if 42 <= h < 50:        # oranges -> apricot
        return h + 22 * t
    if 5 <= h < 42:         # reds and vermilions -> coral, away from pink
        return h + 5 * t
    return h


# ── Reading the wallpaper ─────────────────────────────────────────────────

NEUTRAL_C = 0.03   # below this (Oklab chroma) a pixel is ink or paper, not a colour
MERGE = 0.035      # a/b distance under which two clusters are one colour
K = 8              # clusters tried before merging


class Family:
    """One colour of the wallpaper: its pixels (L, C, h, weight)."""

    def __init__(self, members):
        self.members = members

    @property
    def share(self) -> float:
        return sum(m[3] for m in self.members)

    @property
    def hue(self) -> float:
        x = sum(w * C * math.cos(math.radians(h)) for _, C, h, w in self.members)
        y = sum(w * C * math.sin(math.radians(h)) for _, C, h, w in self.members)
        return math.degrees(math.atan2(y, x)) % 360

    @property
    def chroma(self) -> float:
        # Intensity: the vivid end of the colour (its 80th percentile by
        # weight), so a few vivid pixels among dull ones still count.
        ms = sorted(self.members, key=lambda m: m[1])
        total, acc = self.share, 0.0
        for _, C, _, w in ms:
            acc += w
            if acc >= total * 0.8:
                return C
        return ms[-1][1]

    @property
    def lightness(self) -> float:
        return sum(L * w for L, _, _, w in self.members) / self.share

    def describe(self) -> dict:
        # hex: the pigment as it is in the picture (its hue, vivid chroma and
        # mean lightness, fitted into sRGB), for the theme's accent tokens.
        return {"hue": round(self.hue, 1), "share": round(self.share, 4), "chroma": round(self.chroma, 4),
                "lightness": round(self.lightness, 3), "hex": "#%06x" % (oklch(self.lightness, self.chroma, self.hue) & 0xFFFFFF)}


def pixels(path: str) -> list[tuple[float, float, float, float]]:
    """The picture as (L, a, b, weight) cells: averaged down in Oklab to about
    96 px wide, each weighted by its place (centre 1, borders 0.3)."""
    with Image.open(path) as img:
        img = img.convert("RGB")
        w0 = 192
        h0 = max(2, round(img.height * w0 / img.width))
        img = img.resize((w0, h0), Image.Resampling.BOX)
        data = list(img.getdata())
    lab = [rgb_to_oklab(*p) for p in data]
    w, h = w0 // 2, h0 // 2
    out = []
    for y in range(h):
        for x in range(w):
            cells = [lab[(2 * y + dy) * w0 + 2 * x + dx] for dy in (0, 1) for dx in (0, 1)]
            L = sum(c[0] for c in cells) / 4
            a = sum(c[1] for c in cells) / 4
            b = sum(c[2] for c in cells) / 4
            # Centre weight: full inside the middle 50%, linear to 0.3 at the edges.
            fx = max(0.0, abs((x + 0.5) / w - 0.5) - 0.25) / 0.25
            fy = max(0.0, abs((y + 0.5) / h - 0.5) - 0.25) / 0.25
            out.append((L, a, b, 1.0 - 0.7 * max(fx, fy)))
    total = sum(p[3] for p in out)
    return [(L, a, b, wt / total) for L, a, b, wt in out]


def kmeans(points: list[tuple[float, float, float]], k: int) -> list[list[int]]:
    """Weighted k-means++ on (a, b, weight) points, deterministic (each new
    centre is the point farthest, by weighted distance, from those chosen),
    then clusters closer than MERGE merged into one colour."""
    if not points:
        return []
    centres = [max(points, key=lambda p: p[2])[:2]]
    while len(centres) < min(k, len(points)):
        far = max(points, key=lambda p: p[2] * min(math.dist(p[:2], c) for c in centres) ** 2)
        if min(math.dist(far[:2], c) for c in centres) < 1e-4:
            break
        centres.append(far[:2])
    assign = [0] * len(points)
    for _ in range(12):
        for i, p in enumerate(points):
            assign[i] = min(range(len(centres)), key=lambda c: math.dist(p[:2], centres[c]))
        moved = False
        for c in range(len(centres)):
            mem = [points[i] for i in range(len(points)) if assign[i] == c]
            wsum = sum(m[2] for m in mem)
            if wsum <= 0:
                continue
            new = (sum(m[0] * m[2] for m in mem) / wsum, sum(m[1] * m[2] for m in mem) / wsum)
            moved |= math.dist(new, centres[c]) > 1e-5
            centres[c] = new
        if not moved:
            break
    groups = [[i for i in range(len(points)) if assign[i] == c] for c in range(len(centres))]
    groups = [g for g in groups if g]
    merged = True
    while merged:
        merged = False
        cents = []
        for g in groups:
            wsum = sum(points[i][2] for i in g) or 1
            cents.append((sum(points[i][0] * points[i][2] for i in g) / wsum,
                          sum(points[i][1] * points[i][2] for i in g) / wsum))
        for i in range(len(groups)):
            for j in range(i + 1, len(groups)):
                if math.dist(cents[i], cents[j]) < MERGE:
                    groups[i] += groups.pop(j)
                    merged = True
                    break
            if merged:
                break
    return groups


def read(path: str) -> dict:
    cells = pixels(path)
    lch = [(L, math.hypot(a, b), math.degrees(math.atan2(b, a)) % 360, w) for L, a, b, w in cells]

    def tone(items, lo, hi):
        sel = [c for c in items if lo <= c[0] <= hi]
        w = sum(c[3] for c in sel)
        if w <= 0:
            return None
        x = sum(c[1] * c[3] * math.cos(math.radians(c[2])) for c in sel) / w
        y = sum(c[1] * c[3] * math.sin(math.radians(c[2])) for c in sel) / w
        return {"L": sum(c[0] * c[3] for c in sel) / w, "C": math.hypot(x, y),
                "h": math.degrees(math.atan2(y, x)) % 360, "share": w}

    neutral = [c for c in lch if c[1] < NEUTRAL_C]
    colour = [c for c in lch if c[1] >= NEUTRAL_C]
    # Paper and ink: the light and dark of the picture (low-chroma pixels).
    soft = [c for c in lch if c[1] < NEUTRAL_C * 2]
    paper = tone(soft, 0.62, 1.01)
    ink = tone(soft, -0.01, 0.42)

    points = [(C * math.cos(math.radians(h)), C * math.sin(math.radians(h)), w) for _, C, h, w in colour]
    families = [Family([colour[i] for i in g]) for g in kmeans(points, K)]
    return {"families": families, "paper": paper, "ink": ink,
            "neutralShare": sum(c[3] for c in neutral), "colourShare": sum(c[3] for c in colour)}


# ── Choosing the colours ──────────────────────────────────────────────────


def salience(f: Family) -> float:
    return (f.share ** 0.6) * ((f.chroma / 0.15) ** 1.2)


def choose(r: dict) -> dict:
    # Too little to matter: dropped (under 0.5% of the picture, weighted).
    fams = sorted((f for f in r["families"] if f.share >= 0.005), key=lambda f: -f.share)
    if not fams:
        return {"lead": None, "pop": None, "second": None, "whispers": []}

    # Clusters a few degrees apart in hue are one colour to the eye (an ochre
    # and a paler yellow are both "the yellow").
    merged: list[Family] = []
    for f in fams:
        same = next((m for m in merged if hue_diff(m.hue, f.hue) < 8), None)
        if same:
            same.members += f.members
        else:
            merged.append(Family(list(f.members)))
    fams = sorted(merged, key=lambda f: -f.share)

    # The lead: what the picture is mostly made of (coverage first, a touch of
    # intensity to break near-ties).
    lead = max(fams, key=lambda f: f.share * (0.6 + f.chroma / 0.25))
    rest = [f for f in fams if f is not lead and hue_diff(f.hue, lead.hue) > 18]

    # The pop: the most vivid of the rest, if it's really present.
    pops = [f for f in rest if f.share >= 0.01 and f.chroma >= 0.08]
    pop = max(pops, key=lambda f: f.chroma * f.share ** 0.35, default=None)
    rest = [f for f in rest if f is not pop]

    # Second: the next real colour that's clearly there (not the pop again).
    seconds = [f for f in rest if (f.share >= 0.02 or salience(f) >= 0.08)
               and (pop is None or hue_diff(f.hue, pop.hue) > 8 or abs(f.chroma - pop.chroma) > 0.04)]
    second = max(seconds, key=salience, default=None)
    rest = [f for f in rest if f is not second]

    # Whispers: weak colours, kept only as quiet tints (terminal colours).
    whispers = [f for f in rest if f.share >= 0.008]
    return {"lead": lead, "pop": pop, "second": second, "whispers": whispers}


# ── Roles ─────────────────────────────────────────────────────────────────


def strength(f: Family | None, lo: float, hi: float, k: float) -> float:
    """An accent's chroma: its colour's intensity scaled, within lo..hi."""
    if f is None:
        return 0.0
    return max(lo, min(hi, f.chroma * k))


# Styles over the same reading (the variants of the `pigment` palette):
#   faithful    the colours as they are (default)
#   vibrant     the lead intensified; surfaces drawn a little toward it
#   expressive  every real colour gets a role of its own, bolder
#   fruitsalad  blends and rotations of what's there (the one that invents)
#   soft        everything quieter
STYLES = {
    "faithful":   dict(lead_k=1.55, lead_lo=0.10, lead_hi=0.15, pop_k=1.0, pop_hi=0.19, sec_k=0.9,
                       tint=0.006, term=1.0, blend=False, spread=False, promote=False),
    "vibrant":    dict(lead_k=1.95, lead_lo=0.13, lead_hi=0.18, pop_k=1.1, pop_hi=0.21, sec_k=1.0,
                       tint=0.014, term=1.15, blend=False, spread=False, promote=False),
    "expressive": dict(lead_k=1.6, lead_lo=0.11, lead_hi=0.16, pop_k=1.1, pop_hi=0.21, sec_k=1.1,
                       tint=0.01, term=1.2, blend=False, spread=True, promote=True),
    "fruitsalad": dict(lead_k=1.45, lead_lo=0.10, lead_hi=0.15, pop_k=1.0, pop_hi=0.18, sec_k=0.9,
                       tint=0.008, term=1.1, blend=True, spread=False, promote=False),
    "soft":       dict(lead_k=0.85, lead_lo=0.06, lead_hi=0.10, pop_k=0.7, pop_hi=0.12, sec_k=0.55,
                       tint=0.0, term=0.75, blend=False, spread=False, promote=False),
}

ANSI_HUES = {"red": 27, "green": 145, "yellow": 95, "blue": 255, "magenta": 335, "cyan": 200}


def roles(r: dict, pick: dict, light: bool, contrast: float = 0.0, style: str = "faithful") -> dict[str, Hct]:
    st = STYLES.get(style, STYLES["faithful"])
    lead, pop, second, whispers = pick["lead"], pick["pop"], pick["second"], pick["whispers"]
    out: dict[str, int] = {}

    def put(name, L, C, h):
        L = max(0.0, min(1.0, L))
        out[name] = oklch(L, max(0.0, C), keep_name(h, L))

    # ── Accents: the real colours (never invented, except fruit salad) ──
    third = second or (max(whispers, key=salience) if whispers and st["promote"] else None)
    lh = lead.hue if lead else 0.0
    ph = pop.hue if pop else None
    if lead is None:
        # No colour in the picture: a black-and-white palette.
        primary = secondary = tertiary = (0.0, 0.0)
    else:
        # A faint colour that covers little stays faint (the picture doesn't
        # feel like it): its floor scales with how present it is.
        presence = 1.0 if lead.chroma >= 0.06 else min(1.0, lead.share / 0.15)
        primary = (lh, strength(lead, st["lead_lo"] * presence, st["lead_hi"], st["lead_k"]))
        if st["blend"]:
            if ph is None:
                ph = (lh + 60) % 360
            d = ((ph - lh + 540) % 360) - 180
            secondary = ((lh + d * 0.5) % 360, 0.07)
            tertiary = (ph, strength(pop, 0.07, st["pop_hi"], st["pop_k"]) if pop else 0.07)
        elif st["spread"]:
            secondary = (ph, strength(pop, 0.07, st["pop_hi"], st["pop_k"])) if pop else \
                ((third.hue, strength(third, 0.05, 0.12, st["sec_k"])) if third else (lh, 0.04))
            if pop and third:
                tertiary = (third.hue, strength(third, 0.06, 0.13, st["sec_k"] * 1.3))
            else:
                tertiary = (lh, strength(lead, 0.03, 0.06, 0.5))
        else:
            secondary = (third.hue, strength(third, 0.035, 0.09, st["sec_k"])) if third else \
                (lh, strength(lead, 0.03, 0.07, st["sec_k"] * 0.7))
            if pop:
                tertiary = (ph, strength(pop, 0.06, st["pop_hi"], st["pop_k"]))
            elif third:
                tertiary = (third.hue, strength(third, 0.05, 0.12, st["sec_k"] * 1.2))
            else:
                tertiary = (lh, strength(lead, 0.03, 0.06, st["sec_k"] * 0.5))

    # ── Surfaces: black and white (the wallpaper's own ink and paper) ──
    # Barely tinted: the ink's or paper's own cast when it has one, plus a
    # trace of the lead colour; none at all for a black-and-white picture.
    tone = r["paper"] if light else r["ink"]
    base_h, base_c = (tone["h"], min(tone["C"], 0.012)) if tone and tone["C"] > 0.004 else (lh, 0.0)
    if lead is not None and st["tint"] > 0:
        if base_c < 0.004:
            base_h = lh
        base_c = min(0.02, base_c + st["tint"])
    cboost = 1 + contrast * 0.5

    if light:
        surf = {"surfaceContainerLowest": 1.0, "surfaceContainerLow": 0.965, "surface": 0.975,
                "surfaceContainer": 0.945, "surfaceContainerHigh": 0.925, "surfaceContainerHighest": 0.905,
                "surfaceDim": 0.88, "surfaceBright": 0.985}
    else:
        surf = {"surfaceContainerLowest": 0.10, "surfaceDim": 0.14, "surface": 0.17,
                "surfaceContainerLow": 0.20, "surfaceContainer": 0.23, "surfaceContainerHigh": 0.26,
                "surfaceContainerHighest": 0.29, "surfaceBright": 0.33}
    for name, L in surf.items():
        put(name, L, base_c, base_h)
    out["background"] = out["surface"]
    out["surfaceVariant"] = out["surfaceContainerHighest"]

    tc = min(base_c, 0.01)
    if light:
        put("onSurface", 0.20 / cboost, tc, base_h)
        put("onSurfaceVariant", 0.40, tc, base_h)
        put("outline", 0.60, tc, base_h)
        put("outlineVariant", 0.84, tc, base_h)
        put("inverseSurface", 0.24, tc, base_h)
        put("inverseOnSurface", 0.95, base_c, base_h)
    else:
        put("onSurface", min(0.98, 0.93 * cboost), tc, base_h)
        put("onSurfaceVariant", 0.80, tc, base_h)
        put("outline", 0.60, tc, base_h)
        put("outlineVariant", 0.36, tc, base_h)
        put("inverseSurface", 0.92, tc, base_h)
        put("inverseOnSurface", 0.22, base_c, base_h)
    out["onBackground"] = out["onSurface"]

    # ── Accent roles ──
    accents = {"primary": primary, "secondary": secondary, "tertiary": tertiary}
    # Monochrome accents: white, light and mid grey (dark mode); black, dark
    # and mid grey (light mode).
    mono_L = {"primary": (0.94, 0.25), "secondary": (0.82, 0.38), "tertiary": (0.70, 0.50)}
    for name, (h, C) in accents.items():
        mono = C <= 0.0
        cap = name[0].upper() + name[1:]
        if light:
            L = mono_L[name][1] if mono else (0.70 if name == "primary" else 0.62)
            put(name, L, C * 1.1, h)
            put(f"on{cap}", 0.98 if mono else 0.22, C * 0.4, h)
            put(f"{name}Container", 0.89, 0.0 if mono else max(C * 0.6, 0.06), h)
            put(f"on{cap}Container", 0.24, C * 0.8, h)
            put(f"{name}Dim", L - 0.06, C, h)
            if name == "primary":
                put("inversePrimary", 0.82, C, h)
        else:
            if mono:
                L = mono_L[name][0]
            elif name == "tertiary":
                L = 0.68 if st["pop_k"] >= 1 else 0.78
            else:
                L = 0.80 if name == "primary" and st["lead_k"] >= 1.9 else 0.84
            put(name, L, C, h)
            put(f"on{cap}", 0.20 if mono else 0.26, C * 0.45, h)
            # Containers: the colour, light, written on in dark ink (a red's
            # sits deeper: lighter, it can only turn pink). Monochrome: a mid
            # grey with white text.
            if mono:
                put(f"{name}Container", 0.36, 0.0, h)
                put(f"on{cap}Container", 0.93, 0.0, h)
            else:
                redish = 5 <= h % 360 < 42
                put(f"{name}Container", 0.68 if redish else 0.74,
                    max(C * 1.1, 0.12) if hue_diff(h, 50) < 45 else C * 0.8, h)
                put(f"on{cap}Container", 0.24, C * 0.55, h)
            put(f"{name}Dim", L - 0.08, C * 0.9, h)
            if name == "primary":
                put("inversePrimary", 0.45, C, h)
        put(f"{name}Fixed", 0.90, C * 0.55, h)
        put(f"{name}FixedDim", 0.82, C * 0.8, h)
        put(f"on{cap}Fixed", 0.22, C * 0.5, h)
        put(f"on{cap}FixedVariant", 0.38, C * 0.6, h)
        put(f"{name}PaletteKeyColor", 0.62, C * 1.4, h)

    # Error: cinnabar (errors stay red on any wallpaper), nudged away from a
    # red accent so the two stay apart.
    eh = 25.0
    near = [h for h, C in accents.values() if C > 0 and hue_diff(h, eh) < 20]
    if near:
        eh = (near[0] - 18) % 360
    if light:
        put("error", 0.52, 0.16, eh)
        put("onError", 0.98, 0.01, eh)
        put("errorContainer", 0.89, 0.06, eh)
        put("onErrorContainer", 0.30, 0.10, eh)
        put("errorDim", 0.46, 0.15, eh)
    else:
        put("error", 0.74, 0.14, eh)
        put("onError", 0.25, 0.07, eh)
        put("errorContainer", 0.40, 0.10, eh)
        put("onErrorContainer", 0.92, 0.05, eh)
        put("errorDim", 0.68, 0.13, eh)
    put("errorPaletteKeyColor", 0.62, 0.17, eh)
    put("neutralPaletteKeyColor", 0.6, base_c, base_h)
    put("neutralVariantPaletteKeyColor", 0.6, base_c * 1.5, base_h)
    out["surfaceTint"] = out["primary"]
    out["shadow"] = 0xFF000000
    out["scrim"] = 0xFF000000

    # Terminal: each ANSI colour takes the wallpaper's colour of that hue
    # when there is one, else a quiet version of itself (terminals need all
    # six to stay readable, even on a black-and-white wallpaper).
    fams = [f for f in (lead, pop, second, *whispers) if f]
    for i, (name, h) in enumerate(ANSI_HUES.items(), start=1):
        near_f = min(fams, key=lambda f: hue_diff(f.hue, h), default=None)
        if near_f and hue_diff(near_f.hue, h) < 35:
            hue = near_f.hue + (h - near_f.hue) * 0.25
            C = strength(near_f, 0.06, 0.13 * st["term"], 0.7 * st["term"])
        else:
            hue, C = h, 0.045 * st["term"]
        if light:
            put(f"term{i}", 0.50, C, hue)
            put(f"term{i + 8}", 0.42, C * 1.1, hue)
        else:
            put(f"term{i}", 0.72, C, hue)
            put(f"term{i + 8}", 0.82, C * 0.9, hue)
    if light:
        put("term0", 0.96, base_c, base_h)
        put("term8", 0.62, tc, base_h)
        put("term7", 0.30, tc, base_h)
        put("term15", 0.18, tc, base_h)
    else:
        put("term0", 0.20, base_c, base_h)
        put("term8", 0.45, tc, base_h)
        put("term7", 0.82, tc, base_h)
        put("term15", 0.95, tc, base_h)

    return {k: Hct.from_int(v) for k, v in out.items()}


def generate(image: str, light: bool, contrast: float = 0.0, style: str = "faithful") -> tuple[dict[str, Hct], dict]:
    """The scheme for `image`, and a description of what was read."""
    r = read(image)
    pick = choose(r)
    desc = {
        "lead": pick["lead"].describe() if pick["lead"] else None,
        "pop": pick["pop"].describe() if pick["pop"] else None,
        "second": pick["second"].describe() if pick["second"] else None,
        "whispers": [f.describe() for f in pick["whispers"]],
        "colourShare": round(r["colourShare"], 4),
        "paper": r["paper"], "ink": r["ink"], "style": style,
    }
    return roles(r, pick, light, contrast, style), desc
