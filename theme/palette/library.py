#!/usr/bin/env python3
"""The wallpaper library's index, for the shell's picker (stage W1).

The idea is Ryoku's (ryogami's daemon indexes every wallpaper with a thumbnail
and its colour: hue bucket, saturation, "richness"), done with the shell's own
colour reading (pigment.py): each wallpaper's lead pigment (the colour the
theme would build on), how vivid it is, whether it's really black and white,
and how light it is, so the picker can filter by what a wallpaper *is*.

    library.py ROOT INDEX.json THUMBS_DIR [--force]

Incremental: a wallpaper whose size and mtime haven't changed keeps its entry.
Progress is NDJSON on stdout ({"done": n, "total": m}), the index is written
atomically at the end (and every 40 new entries, so a long first run shows
up as it goes).

Entry: { path, name, folder, mtime, size, w, h, thumb, hue, bucket, chroma,
         lightness, neutral, colours: ["#rrggbb", …] }
  bucket  0..11: the lead pigment's hue in twelve steps of 30° (0 = red);
          99: black and white / neutral (Ryoku's numbering)
"""

from __future__ import annotations

import hashlib
import json
import os
import sys
import tempfile
from pathlib import Path

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pigment  # noqa: E402

EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}
# Live wallpapers: indexed from a frame a second in.
VIDEO = {".mp4", ".webm", ".mkv", ".mov", ".m4v"}
# Wide enough for a strip card or mosaic tile at full sharpness (480 looked
# grainy); the open slice decodes the file itself.
THUMB_W = 720
THUMB_Q = 88


def write_atomic(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=".library-")
    with os.fdopen(fd, "w") as f:
        json.dump(data, f, separators=(",", ":"))
    os.replace(tmp, path)


# Live wallpapers can play from a copy at 1080p or 720p (the "Live wallpaper
# resolution" setting; Ryoku converts them too): lighter for 4K videos
# (measured over a still: 4K +345 MB / 12% CPU, 1080p +137 MB / 8%).
def _live_size():
    for a in sys.argv:
        if a.startswith("--live-copies="):
            h = int(a.split("=", 1)[1])
            return (h * 16 // 9, h)
    return None


SCREEN = _live_size() or (1920, 1080)
LIVE_COPIES = _live_size() is not None


def live_copy(path: Path, key: str, live_dir: Path) -> str:
    """A copy of a video at the chosen size (H.264, no audio), made once; ""
    if the original is that small already or the conversion failed."""
    import subprocess
    probe = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height",
                            "-of", "csv=p=0", str(path)], capture_output=True, text=True, timeout=30)
    try:
        w, h = (int(x) for x in probe.stdout.strip().split(",")[:2])
    except ValueError:
        return ""
    if w <= SCREEN[0] * 1.1 and h <= SCREEN[1] * 1.1:
        return ""
    out = live_dir / f"{key}-{SCREEN[1]}.mp4"
    if out.exists():
        return str(out)
    live_dir.mkdir(parents=True, exist_ok=True)
    tmp = out.with_suffix(".part.mp4")
    # Cover the screen (the shorter side fits), Lanczos, near-transparent
    # quality (CRF 16, a slower preset): it shouldn't look converted.
    scale = (f"scale={SCREEN[0]}:{SCREEN[1]}:force_original_aspect_ratio=increase:flags=lanczos,"
             "scale=trunc(iw/2)*2:trunc(ih/2)*2:flags=lanczos")
    res = subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(path), "-vf", scale, "-c:v", "libx264", "-preset", "slow",
                          "-crf", "16", "-tune", "film", "-pix_fmt", "yuv420p", "-an", "-movflags", "+faststart", str(tmp)],
                         timeout=3600)
    if res.returncode != 0:
        tmp.unlink(missing_ok=True)
        return ""
    os.replace(tmp, out)
    return str(out)


def anim_preview(path: Path, key: str, thumbs: Path) -> str:
    """A live wallpaper's preview for the picker: three seconds at 12 fps,
    720 px wide, as an animated WebP (a GIF's job with far better colour, a
    tenth of the size; ~0.5 MB), instead of decoding the video there."""
    import subprocess
    out = thumbs / f"{key}.anim.webp"
    if out.exists():
        return str(out)
    tmp = thumbs / f"{key}.anim.part.webp"
    res = subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", "1", "-t", "3", "-i", str(path),
                          "-vf", "fps=12,scale=720:-2:flags=lanczos", "-loop", "0", "-c:v", "libwebp_anim",
                          "-quality", "72", "-compression_level", "4", str(tmp)], timeout=300)
    if res.returncode != 0:
        tmp.unlink(missing_ok=True)
        return ""
    os.replace(tmp, out)
    return str(out)


def entry_for(path: Path, root: Path, thumbs: Path) -> dict:
    st = path.stat()
    key = hashlib.sha1(f"{path}|{st.st_size}|{int(st.st_mtime)}|{THUMB_W}".encode()).hexdigest()[:20]
    thumb = thumbs / f"{key}.webp"
    video = path.suffix.lower() in VIDEO
    frame = None
    if video:
        frame = thumbs / f"{key}.frame.png"
        if not thumb.exists() and not frame.exists():
            import subprocess
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-ss", "1", "-i", str(path), "-frames:v", "1", str(frame)],
                           check=True, timeout=60)
    with Image.open(frame if (video and frame.exists()) else path if not video else thumb) as img:
        w, h = img.size
        if not thumb.exists():
            img = img.convert("RGB")
            img.thumbnail((THUMB_W, THUMB_W * 2), Image.Resampling.LANCZOS)
            thumb.parent.mkdir(parents=True, exist_ok=True)
            # Written aside and moved in: a reader never sees half a file.
            tmp = thumb.with_suffix(".part")
            img.save(tmp, "WEBP", quality=THUMB_Q, method=4)
            os.replace(tmp, thumb)
    if frame is not None:
        frame.unlink(missing_ok=True)

    # The colour, from the thumbnail (pigment averages down to ~96 px anyway).
    r = pigment.read(str(thumb))
    pick = pigment.choose(r)
    lead = pick["lead"]
    families = sorted(r["families"], key=lambda f: -f.share)
    colours = ["#%06x" % (pigment.oklch(f.lightness, f.chroma, f.hue) & 0xFFFFFF) for f in families[:4] if f.share > 0.02]
    # Mean lightness: paper, ink and the colour families, by share.
    parts = [(t["L"], t["share"]) for t in (r["paper"], r["ink"]) if t] + [(f.lightness, f.share) for f in families]
    total = sum(s for _, s in parts) or 1
    lightness = sum(l * s for l, s in parts) / total

    rel = path.relative_to(root)
    return {
        "path": str(path),
        "name": path.name,
        "folder": rel.parts[0] if len(rel.parts) > 1 else "",
        "mtime": int(st.st_mtime),
        "size": st.st_size,
        "w": w,
        "h": h,
        "thumb": str(thumb),
        "video": video,
        "preview": anim_preview(path, key, thumbs) if video else "",
        "live": live_copy(path, key, thumbs.parent / "live") if video and LIVE_COPIES else "",
        "thumbW": THUMB_W,
        "hue": round(lead.hue, 1) if lead else None,
        "bucket": int(((lead.hue + 15) % 360) // 30) if lead else 99,
        "chroma": round(lead.chroma, 4) if lead else 0.0,
        "lightness": round(lightness, 3),
        "neutral": lead is None,
        "colours": colours,
    }


def main() -> int:
    if len(sys.argv) < 4:
        print(__doc__, file=sys.stderr)
        return 2
    root, index_path, thumbs = Path(sys.argv[1]).expanduser(), Path(sys.argv[2]), Path(sys.argv[3])
    force = "--force" in sys.argv[4:]
    try:
        old = {e["path"]: e for e in json.loads(index_path.read_text()).get("wallpapers", [])}
    except (OSError, ValueError):
        old = {}

    files = sorted(p for p in root.rglob("*") if p.is_file() and p.suffix.lower() in EXTS | VIDEO and not any(part.startswith(".") for part in p.relative_to(root).parts))
    out, fresh = [], 0
    for i, path in enumerate(files):
        prev = old.get(str(path))
        try:
            st = path.stat()
            if prev and not force and prev.get("size") == st.st_size and prev.get("mtime") == int(st.st_mtime) and prev.get("thumbW") == THUMB_W and Path(prev.get("thumb", "")).exists() and (not prev.get("video") or bool(prev.get("preview"))) and (not prev.get("video") or not LIVE_COPIES or f"-{SCREEN[1]}." in prev.get("live", "")):
                out.append(prev)
            else:
                out.append(entry_for(path, root, thumbs))
                fresh += 1
                if fresh % 40 == 0:
                    write_atomic(index_path, {"root": str(root), "wallpapers": out + [e for p, e in old.items() if p not in {o["path"] for o in out}]})
        except Exception as e:  # a broken file shouldn't stop the rest
            print(json.dumps({"error": str(path), "why": str(e)[:200]}), flush=True)
        if fresh and (i % 5 == 0 or i == len(files) - 1):
            print(json.dumps({"done": i + 1, "total": len(files), "new": fresh}), flush=True)

    write_atomic(index_path, {"root": str(root), "wallpapers": out})
    # Thumbnails nothing points at any more (older sizes, removed files).
    keep = {e["thumb"] for e in out} | {e["preview"] for e in out if e.get("preview")}
    # Copies nothing uses (the setting went back to original, a video left).
    keep_live = {e.get("live") for e in out if e.get("live")} if LIVE_COPIES else set()
    for v in (thumbs.parent / "live").glob("*.mp4"):
        if str(v) not in keep_live:
            v.unlink(missing_ok=True)
    for t in thumbs.glob("*.webp"):
        if str(t) not in keep:
            t.unlink(missing_ok=True)
    print(json.dumps({"done": len(files), "total": len(files), "new": fresh, "finished": True}), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
