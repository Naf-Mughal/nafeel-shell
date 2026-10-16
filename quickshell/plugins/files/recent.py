#!/usr/bin/env python3
"""The launcher's recent files: JSON on stdout.

    recent.py <root> [<root> ...]

What you opened lately (~/.local/share/recently-used.xbel, which GTK and Qt
file dialogs and many apps add to), then what changed lately in the folders
(the last three days, fd; gitignored, hidden and cache files skipped), the
newest first. [{ "path": ..., "t": epoch seconds, "why": "opened" | "changed" }]
"""
import json
import os
import re
import subprocess
import sys
import time
import urllib.parse
from datetime import datetime

SKIP = re.compile(r"(\.(log|tmp|lock|swp|pyc|o|map)$|~$|/node_modules/|/__pycache__/|package-lock\.json$)")


def opened() -> dict[str, float]:
    out = {}
    try:
        text = open(os.path.expanduser("~/.local/share/recently-used.xbel"), encoding="utf8").read()
    except OSError:
        return out
    for m in re.finditer(r'<bookmark href="([^"]+)"[^>]*?visited="([^"]+)"', text):
        href, visited = m.groups()
        if not href.startswith("file://"):
            continue
        path = urllib.parse.unquote(href[7:])
        try:
            t = datetime.fromisoformat(visited.replace("Z", "+00:00")).timestamp()
        except ValueError:
            continue
        if os.path.isfile(path) and not SKIP.search(path):
            out[path] = t
    return out


def changed(roots: list[str]) -> dict[str, float]:
    out = {}
    cmd = ["fd", "-t", "f", "--changed-within", "3d", "--exclude", "node_modules", "--exclude", ".git", "--exclude", "target", "--exclude", "__pycache__", "--exclude", "build", "--exclude", "dist", ".", *roots]
    try:
        files = subprocess.run(cmd, capture_output=True, timeout=10).stdout.decode("utf8", "replace").split("\n")
    except Exception:
        return out
    for p in files:
        if not p or SKIP.search(p):
            continue
        try:
            out[p] = os.stat(p).st_mtime
        except OSError:
            pass
    return out


def main() -> int:
    roots = [os.path.expanduser(r) for r in sys.argv[1:]] or [os.path.expanduser("~")]
    seen = {}
    for p, t in opened().items():
        seen[p] = {"path": p, "t": t, "why": "opened"}
    for p, t in changed(roots).items():
        if p not in seen:
            seen[p] = {"path": p, "t": t, "why": "changed"}
    ordered = sorted(seen.values(), key=lambda e: (e["why"] != "opened", -e["t"]))
    print(json.dumps(ordered[:40]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
