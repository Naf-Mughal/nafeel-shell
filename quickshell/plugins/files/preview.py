#!/usr/bin/env python3
"""The launcher's preview of one file: JSON on stdout.

    preview.py <path> [<line>]

  { "kind": "text" | "image" | "dir" | "none",
    "text": ...,          text: the head of the file, or the lines around
                          <line> (the match); a document: its first page of
                          text; a directory: its entries
    "first": N,           the line number the text starts at (text files)
    "mark": N,            the line to highlight, 1-based within `text`
    "meta": [ "12 KB", "modified 3 days ago", "PDF document", ... ] }

Meant to be cheap: reads at most ~64 KB, never a whole big file.
"""
import importlib.util
import json
import mimetypes
import os
import subprocess
import sys
import time

LIMIT = 65536
DOC_EXT = {".pdf", ".docx", ".pptx", ".xlsx", ".odt", ".ods", ".odp", ".epub"}
IMAGE_EXT = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp", ".avif", ".svg"}


def size(n: int) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024 or unit == "GB":
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1024
    return ""


def ago(t: float) -> str:
    d = time.time() - t
    for span, name in ((86400 * 365, "year"), (86400 * 30, "month"), (86400, "day"), (3600, "hour"), (60, "minute")):
        if d >= span:
            n = int(d // span)
            return f"modified {n} {name}{'s' if n > 1 else ''} ago"
    return "modified just now"


def doc_text(path: str) -> str:
    spec = importlib.util.spec_from_file_location("index_docs", os.path.join(os.path.dirname(os.path.abspath(__file__)), "index-docs.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.extract(path)[:4000]


def main() -> int:
    path = sys.argv[1]
    line = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 0
    out = {"kind": "none", "text": "", "meta": []}
    try:
        st = os.stat(path)
    except OSError:
        print(json.dumps(out))
        return 0
    ext = os.path.splitext(path)[1].lower()
    out["meta"] = [ago(st.st_mtime)]
    if os.path.isdir(path):
        names = sorted(os.listdir(path), key=lambda n: (not os.path.isdir(os.path.join(path, n)), n.lower()))
        out["kind"] = "dir"
        out["text"] = "\n".join(("▸ " if os.path.isdir(os.path.join(path, n)) else "   ") + n for n in names[:40]) + (f"\n… {len(names) - 40} more" if len(names) > 40 else "")
        out["meta"].insert(0, f"{len(names)} items")
    elif ext in IMAGE_EXT:
        out["kind"] = "image"
        out["meta"].insert(0, size(st.st_size))
        try:
            r = subprocess.run(["identify", "-format", "%wx%h", path + "[0]"], capture_output=True, timeout=3)
            if r.stdout:
                out["meta"].insert(1, r.stdout.decode().strip() + " px")
        except Exception:
            pass
    elif ext in DOC_EXT:
        out["kind"] = "text"
        out["meta"].insert(0, size(st.st_size))
        out["meta"].insert(1, {".pdf": "PDF document"}.get(ext, ext[1:].upper() + " document"))
        try:
            out["text"] = "\n".join(l for l in doc_text(path).splitlines() if l.strip())[:3000]
        except Exception:
            out["text"] = ""
    else:
        out["meta"].insert(0, size(st.st_size))
        mime = mimetypes.guess_type(path)[0]
        if mime:
            out["meta"].insert(1, mime)
        with open(path, "rb") as f:
            raw = f.read(LIMIT)
        if b"\0" in raw[:4096]:
            out["kind"] = "none"
        else:
            out["kind"] = "text"
            lines = raw.decode("utf8", "replace").split("\n")
            if line > 0:
                first = max(1, line - 8)
                window = lines[first - 1:first + 18]
                # The match may be past the first 64 KB: read on.
                if line > len(lines) - 2 and st.st_size > LIMIT:
                    with open(path, "r", encoding="utf8", errors="replace") as f:
                        all_lines = f.readlines()
                    window = [l.rstrip("\n") for l in all_lines[first - 1:first + 18]]
                out["first"] = first
                out["mark"] = line - first + 1
                out["text"] = "\n".join(window)
            else:
                out["first"] = 1
                out["text"] = "\n".join(lines[:30])
    print(json.dumps(out, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
