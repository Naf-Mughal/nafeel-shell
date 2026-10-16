#!/usr/bin/env python3
"""The launcher's document index: the text of PDFs and office documents,
extracted into a cache the launcher searches with ripgrep.

    index-docs.py <cache dir> <root> [<root> ...]

Per document, <cache>/<sha1 of its path>.txt: a first line "# <path>", then
the text. <cache>/index.tsv lists them (hash, mtime, size, path); only new or
changed documents are read again, deleted ones are dropped. Meant to run
niced and at idle (the shell starts it so); one document at a time.

PDFs by pdftotext; docx / pptx / xlsx / odt / ods / odp / epub are zips of
XML or HTML, read here with the standard library. Scanned PDFs are pictures
with no text to find (no OCR).
"""
import hashlib
import html
import os
import re
import subprocess
import sys
import time
import zipfile

EXT = {".pdf", ".docx", ".pptx", ".xlsx", ".odt", ".ods", ".odp", ".epub"}
SKIP_DIRS = {"node_modules", ".git", "target", "__pycache__", ".cache", ".venv", "venv", "site-packages", "build", "dist"}
MAX_TEXT = 2_000_000
TAG = re.compile(r"<[^>]+>")


def strip(xml: str, breaks: tuple[str, ...]) -> str:
    for b in breaks:
        xml = xml.replace(b, "\n")
    return html.unescape(TAG.sub("", xml))


def zip_text(path: str, ext: str) -> str:
    out = []
    with zipfile.ZipFile(path) as z:
        names = z.namelist()
        if ext == ".docx":
            out.append(strip(z.read("word/document.xml").decode("utf8", "ignore"), ("</w:p>", "<w:br/>", "<w:tab/>")))
        elif ext == ".pptx":
            for n in sorted(x for x in names if re.fullmatch(r"ppt/slides/slide\d+\.xml", x)):
                out.append(strip(z.read(n).decode("utf8", "ignore"), ("</a:p>",)))
        elif ext == ".xlsx":
            if "xl/sharedStrings.xml" in names:
                out.append(strip(z.read("xl/sharedStrings.xml").decode("utf8", "ignore"), ("</si>",)))
        elif ext in (".odt", ".ods", ".odp"):
            out.append(strip(z.read("content.xml").decode("utf8", "ignore"), ("</text:p>", "</text:h>", "<text:line-break/>")))
        elif ext == ".epub":
            for n in names:
                if n.lower().endswith((".xhtml", ".html", ".htm")):
                    out.append(strip(z.read(n).decode("utf8", "ignore"), ("</p>", "</div>", "</h1>", "</h2>", "</h3>", "<br/>", "<br>")))
    return "\n".join(out)


def extract(path: str) -> str:
    ext = os.path.splitext(path)[1].lower()
    if ext == ".pdf":
        r = subprocess.run(["pdftotext", "-q", "-enc", "UTF-8", path, "-"], capture_output=True, timeout=90)
        return r.stdout.decode("utf8", "ignore").replace("\f", "\n")
    return zip_text(path, ext)


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    cache, roots = os.path.abspath(sys.argv[1]), [os.path.abspath(os.path.expanduser(r)) for r in sys.argv[2:]]
    os.makedirs(cache, exist_ok=True)
    index = os.path.join(cache, "index.tsv")
    old = {}
    try:
        for line in open(index, encoding="utf8"):
            h, m, s, p = line.rstrip("\n").split("\t", 3)
            old[p] = (h, m, s)
    except OSError:
        pass

    found = {}
    for root in roots:
        for dirpath, dirs, files in os.walk(os.path.expanduser(root)):
            dirs[:] = [d for d in dirs if not d.startswith(".") and d not in SKIP_DIRS and os.path.join(dirpath, d) != cache]
            for f in files:
                if os.path.splitext(f)[1].lower() in EXT and not f.startswith((".", "~$")):
                    p = os.path.join(dirpath, f)
                    try:
                        st = os.stat(p)
                    except OSError:
                        continue
                    found[p] = (str(int(st.st_mtime)), str(st.st_size))

    done = read = failed = 0
    new = {}
    t0 = time.time()
    for p, (m, s) in found.items():
        h = hashlib.sha1(p.encode()).hexdigest()
        if p in old and old[p][1] == m and old[p][2] == s and os.path.exists(os.path.join(cache, h + ".txt")):
            new[p] = (h, m, s)
            continue
        try:
            text = extract(p)[:MAX_TEXT]
        except Exception as e:  # a broken or encrypted file: indexed without text, not retried until it changes
            text = ""
            failed += 1
        tmp = os.path.join(cache, h + ".tmp")
        with open(tmp, "w", encoding="utf8") as out:
            out.write("# " + p + "\n" + re.sub(r"[ \t]+", " ", text))
        os.replace(tmp, os.path.join(cache, h + ".txt"))
        new[p] = (h, m, s)
        read += 1
        time.sleep(0.02)
    for p, (h, m, s) in old.items():
        if p not in new:
            try:
                os.remove(os.path.join(cache, h + ".txt"))
            except OSError:
                pass
    tmp = index + ".tmp"
    with open(tmp, "w", encoding="utf8") as out:
        for p, (h, m, s) in new.items():
            out.write(f"{h}\t{m}\t{s}\t{p}\n")
    os.replace(tmp, index)
    print(f"index-docs: {len(new)} documents, {read} read, {failed} without text, {time.time() - t0:.1f}s")
    return 0


if __name__ == "__main__":
    sys.exit(main())
