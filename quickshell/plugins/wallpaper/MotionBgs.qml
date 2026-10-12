// Live wallpapers from motionbgs.com in the store: search (or, with no query,
// the latest, a page at a time), previews, and downloads from the site's own
// download links (/dl/4k/<id>, /dl/hd/<id>) into ~/Pictures/Wallpapers/live.
// The site has no API, so its result pages are read for title, id and
// thumbnail; if its markup changes, results come back empty (and the store
// says so) rather than anything breaking.
//
// (moewalls.com was looked at too: its downloads sit behind an encoded,
// ad-gated token, so it isn't offered.)
//
// Bus: "store.downloaded" { id, path } as the Wallhaven store.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

Scope {
    id: root

    readonly property string site: "https://motionbgs.com"
    readonly property string dir: Quickshell.env("HOME") + "/Pictures/Wallpapers/live"
    readonly property string userAgent: "Mozilla/5.0 (X11; Linux x86_64) nafeel-shell"

    property string query: ""
    // "4k" or "hd" (1080p) when both are offered.
    property string quality: "4k"
    property var results: []
    property int page: 0
    property bool hasMore: false
    property bool loading: false
    property string error: ""
    property bool started: false

    property var status: ({})
    property var progress: ({})
    property var local: ({})

    function search(): void {
        started = true;
        results = [];
        page = 0;
        _fetch(1);
    }

    function more(): void {
        if (!loading && hasMore)
            _fetch(page + 1);
    }

    function _fetch(p: int): void {
        loading = true;
        error = "";
        const url = query ? `${site}/search?q=${encodeURIComponent(query)}` : p > 1 ? `${site}/${p}/` : `${site}/`;
        fetcher.pageNo = p;
        fetcher.command = ["curl", "-fsSL", "--max-time", "20", "-A", userAgent, url];
        fetcher.running = true;
    }

    onQueryChanged: if (started)
        again.restart()

    Timer {
        id: again

        interval: 500
        onTriggered: root.search()
    }

    // The result grid: <a title=… href=/slug> … /media/<id>/<file>.jpg …
    // <span class=ttl>Title</span> <span class=frm> 4K </span>
    function parse(html: string): var {
        const out = [];
        const re = /<a title="[^"]*" href=\/([a-z0-9-]+)>([\s\S]*?)<\/a>/g;
        let m;
        while ((m = re.exec(html)) !== null) {
            const body = m[2];
            const media = body.match(/\/i\/c\/546x308\/media\/(\d+)\/([^ >"]+?)\.(jpg|png)(?:\.webp)?/);
            const title = body.match(/<span class=ttl>([^<]*)<\/span>/);
            if (!media || !title)
                continue;
            const fmt = (body.match(/<span class=frm>\s*([^<]*?)\s*<\/span>/) ?? [])[1] ?? "";
            out.push({
                id: "mbg-" + media[1],
                mid: media[1],
                slug: m[1],
                remote: true,
                video: true,
                provider: "motionbgs",
                name: title[1].replace(/&#39;/g, "'").replace(/&amp;/g, "&"),
                path: "",
                thumbUrl: `${site}/i/c/546x308/media/${media[1]}/${media[2]}.${media[3]}`,
                full: `${site}/i/c/546x308/media/${media[1]}/${media[2]}.${media[3]}`,
                resolution: fmt || "HD",
                colours: [],
                folder: "live"
            });
        }
        return out;
    }

    Process {
        id: fetcher

        property int pageNo: 1

        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                const items = root.parse(text);
                if (items.length === 0 && fetcher.pageNo === 1)
                    root.error = text ? "Nothing found on motionbgs" : "No answer from motionbgs";
                root.page = fetcher.pageNo;
                // Search answers in one page; browsing goes on.
                root.hasMore = !root.query && items.length > 0;
                const seen = new Set(root.results.map(r => r.id));
                root.results = fetcher.pageNo === 1 ? items : root.results.concat(items.filter(i => !seen.has(i.id)));
                Bus.publish("store.results", {
                    count: root.results.length,
                    page: root.page
                });
            }
        }
        onExited: code => {
            if (code !== 0) {
                root.loading = false;
                root.error = `Network error (curl ${code})`;
            }
        }
    }

    // ── Downloading ──

    function localPath(item: var): string {
        return `${dir}/motionbgs-${item.mid}-${item.slug.replace(/[^a-z0-9-]/g, "")}.mp4`;
    }

    function download(item: var): void {
        if (!item?.mid || status[item.id] === "downloading")
            return;
        if (local[item.id]) {
            Bus.publish("store.downloaded", {
                id: item.id,
                path: localPath(item)
            });
            return;
        }
        const q = quality === "4k" && /4k/i.test(item.resolution) ? "4k" : "hd";
        _set("status", item.id, "downloading");
        _set("progress", item.id, 0);
        dlComponent.createObject(root, {
            job: {
                id: item.id,
                url: `${site}/dl/${q}/${item.mid}/`,
                dest: localPath(item)
            }
        });
    }

    function _set(map: string, id: string, value: var): void {
        const m = Object.assign({}, root[map]);
        m[id] = value;
        root[map] = m;
    }

    Component {
        id: dlComponent

        // curl to a temp file (progress from its bar), `file` checks it's a
        // video, then it's moved into place.
        Process {
            id: dl

            property var job

            command: ["sh", "-c", 'mkdir -p "$(dirname "$2")" && curl -#fSL --max-time 900 -A "$3" -o "$2.part" "$1" && case "$(file -b --mime-type "$2.part")" in video/*) mv -f "$2.part" "$2" ;; *) rm -f "$2.part"; exit 9 ;; esac', "sh", job.url, job.dest, root.userAgent]
            Component.onCompleted: running = true
            stderr: SplitParser {
                splitMarker: "\r"
                onRead: data => {
                    const m = data.match(/([\d.]+)\s*%/);
                    if (m)
                        root._set("progress", dl.job.id, parseFloat(m[1]) / 100);
                }
            }
            onExited: code => {
                root._set("status", dl.job.id, code === 0 ? "done" : "error");
                if (code === 0) {
                    root._set("local", dl.job.id, true);
                    Bus.publish("store.downloaded", {
                        id: dl.job.id,
                        path: dl.job.dest
                    });
                }
                dl.destroy();
            }
        }
    }

    Process {
        running: true
        command: ["sh", "-c", 'ls -1 "$1" 2>/dev/null', "sh", root.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                const ids = {};
                for (const f of text.split("\n")) {
                    const m = f.match(/^motionbgs-(\d+)-/);
                    if (m)
                        ids["mbg-" + m[1]] = true;
                }
                root.local = ids;
            }
        }
    }
}
