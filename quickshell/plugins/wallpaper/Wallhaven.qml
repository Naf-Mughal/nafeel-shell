// The wallpaper store: Wallhaven's search, previews and downloads, inside the
// shell (after Ryoku's WallhavenService and its download process, MIT).
//
// search() asks the API (curl), results come a page at a time (more() for the
// next, the picker asks as you scroll), download(item) fetches the full image
// (three at a time, progress per item), checks it really is an image, and
// moves it into ~/Pictures/Wallpapers/wallhaven/wallhaven-<id>.<ext>; then the
// library picks it up (Wallpapers.rescan) and it can be set like any other.
//
// The API key (optional) is the plugin's "Wallhaven API key" setting: sketchy
// and NSFW results need it.
//
// Bus: "store.results" { count, page, last }, "store.downloaded" { id, path }.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

Scope {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/Pictures/Wallpapers/wallhaven"
    readonly property string userAgent: "Mozilla/5.0 (X11; Linux x86_64) nafeel-shell"

    // ── Search ──
    property string query: ""
    // general / anime / people, as Wallhaven's three bits.
    property bool general: true
    property bool anime: true
    property bool people: false
    // sfw / sketchy / nsfw bits (the last two need the key).
    property bool sfw: true
    property bool sketchy: false
    property bool nsfw: false
    // toplist | date_added | relevance | random | views | favorites | hot
    property string sorting: "toplist"
    // 1d 3d 1w 1M 3M 6M 1y (toplist)
    property string topRange: "1M"
    // "" | "landscape" | "portrait" | "16x9" | "21x9" | …
    property string ratios: "landscape"
    // At least this size ("" = any); the screen's by default.
    property string atleast: Quickshell.screens.length > 0 ? `${Quickshell.screens[0].width}x${Quickshell.screens[0].height}` : ""
    // The picker's colour bucket (0..11, 99 black and white, -1 any), sent as
    // Wallhaven's nearest allowed colour.
    property int colour: -1
    readonly property var colourMap: ({
            0: "ea4c88",
            1: "cc0000",
            2: "ff6600",
            3: "ffcc33",
            4: "669900",
            5: "77cc33",
            6: "66cccc",
            7: "0099cc",
            8: "0066cc",
            9: "333399",
            10: "663399",
            11: "993399",
            99: "999999"
        })

    property var results: []
    property int page: 0
    property int lastPage: 1
    property bool loading: false
    property string error: ""
    readonly property bool hasMore: page < lastPage
    // Has anything been asked yet (the store is opened lazily).
    property bool started: false

    // ── Downloads ──
    // id -> "downloading" | "done" | "error"; id -> 0..1
    property var status: ({})
    property var progress: ({})
    // Ids already in the folder.
    property var local: ({})
    property var _queue: []
    property int _running: 0

    function url(pageNo: int): string {
        const p = [];
        if (query)
            p.push("q=" + encodeURIComponent(query));
        p.push("categories=" + (general ? 1 : 0) + (anime ? 1 : 0) + (people ? 1 : 0));
        const key = Wallpapers.settings.v.wallhavenKey;
        p.push("purity=" + (sfw ? 1 : 0) + (key && sketchy ? 1 : 0) + (key && nsfw ? 1 : 0));
        p.push("sorting=" + sorting, "order=desc");
        if (sorting === "toplist")
            p.push("topRange=" + topRange);
        if (atleast)
            p.push("atleast=" + atleast);
        if (ratios)
            p.push("ratios=" + ratios);
        if (colour >= 0 && colourMap[colour])
            p.push("colors=" + colourMap[colour]);
        p.push("page=" + pageNo);
        if (key)
            p.push("apikey=" + key);
        return "https://wallhaven.cc/api/v1/search?" + p.join("&");
    }

    function search(): void {
        started = true;
        results = [];
        page = 0;
        lastPage = 1;
        _fetch(1);
    }

    function more(): void {
        if (!loading && hasMore)
            _fetch(page + 1);
    }

    function _fetch(pageNo: int): void {
        if (searchProc.running)
            searchProc.running = false;
        loading = true;
        error = "";
        searchProc.command = ["curl", "-fsSL", "--max-time", "20", "-A", userAgent, url(pageNo)];
        searchProc.running = true;
    }

    // Changing a filter searches again (shortly, so typing doesn't flood).
    function _changed(): void {
        if (started)
            again.restart();
    }
    onQueryChanged: _changed()
    onGeneralChanged: _changed()
    onAnimeChanged: _changed()
    onPeopleChanged: _changed()
    onSketchyChanged: _changed()
    onNsfwChanged: _changed()
    onSortingChanged: _changed()
    onTopRangeChanged: _changed()
    onRatiosChanged: _changed()
    onAtleastChanged: _changed()
    onColourChanged: _changed()

    Timer {
        id: again

        interval: 450
        onTriggered: root.search()
    }

    Process {
        id: searchProc

        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                if (!text) {
                    if (!root.error)
                        root.error = "No answer from Wallhaven";
                    return;
                }
                try {
                    const j = JSON.parse(text);
                    if (j.error) {
                        root.error = j.error;
                        return;
                    }
                    const items = (j.data ?? []).map(d => ({
                                id: d.id,
                                remote: true,
                                name: `wallhaven-${d.id}`,
                                path: "",
                                full: d.path,
                                link: d.url,
                                resolution: d.resolution,
                                size: d.file_size,
                                purity: d.purity,
                                category: d.category,
                                thumbUrl: d.thumbs?.large ?? d.thumbs?.original ?? "",
                                colours: (d.colors ?? []).slice(0, 4),
                                folder: "wallhaven"
                            }));
                    root.page = j.meta?.current_page ?? 1;
                    root.lastPage = j.meta?.last_page ?? 1;
                    root.results = root.page === 1 ? items : root.results.concat(items);
                    Bus.publish("store.results", {
                        count: root.results.length,
                        page: root.page,
                        last: root.lastPage
                    });
                } catch (e) {
                    root.error = "Couldn't read Wallhaven's answer";
                }
            }
        }
        onExited: code => {
            if (code !== 0) {
                root.loading = false;
                root.error = code === 22 ? "Wallhaven refused the search (a bad API key, or too many requests)" : `Network error (curl ${code})`;
            }
        }
    }

    // ── Downloading ──

    function localPath(item: var): string {
        const ext = (item.full ?? "").split(".").pop().split("?")[0].toLowerCase();
        return `${dir}/wallhaven-${item.id.replace(/[^a-zA-Z0-9]/g, "")}.${["jpg", "jpeg", "png", "webp"].includes(ext) ? ext : "jpg"}`;
    }

    function download(item: var): void {
        if (!item?.id || status[item.id] === "downloading")
            return;
        if (local[item.id]) {
            Bus.publish("store.downloaded", {
                id: item.id,
                path: localPath(item)
            });
            return;
        }
        // Only Wallhaven's own image host, over https (as Ryoku checks).
        if (!/^https:\/\/w\.wallhaven\.cc\//.test(item.full ?? "")) {
            console.warn("store: refusing", item.full);
            return;
        }
        _set("status", item.id, "downloading");
        _set("progress", item.id, 0);
        _queue.push({
            id: item.id,
            url: item.full,
            dest: localPath(item)
        });
        _drain();
    }

    function _set(map: string, id: string, value: var): void {
        const m = Object.assign({}, root[map]);
        m[id] = value;
        root[map] = m;
    }

    function _drain(): void {
        while (_running < 3 && _queue.length > 0) {
            const job = _queue.shift();
            _running++;
            dlComponent.createObject(root, {
                job
            });
        }
    }

    Component {
        id: dlComponent

        // curl to a temp file (progress from its bar), `file` checks it's an
        // image, then it's moved into place.
        Process {
            id: dl

            property var job

            command: ["sh", "-c", 'mkdir -p "$(dirname "$2")" && curl -#fSL --max-time 300 -A "$3" -o "$2.part" "$1" && case "$(file -b --mime-type "$2.part")" in image/*) mv -f "$2.part" "$2" ;; *) rm -f "$2.part"; exit 9 ;; esac', "sh", job.url, job.dest, root.userAgent]
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
                root._running--;
                root._set("status", dl.job.id, code === 0 ? "done" : "error");
                if (code === 0) {
                    root._set("local", dl.job.id, true);
                    root._set("progress", dl.job.id, 1);
                    Bus.publish("store.downloaded", {
                        id: dl.job.id,
                        path: dl.job.dest
                    });
                }
                root._drain();
                dl.destroy();
            }
        }
    }

    // What's already downloaded.
    function scanLocal(): void {
        localScan.running = true;
    }

    Process {
        id: localScan

        running: true
        command: ["sh", "-c", 'ls -1 "$1" 2>/dev/null', "sh", root.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                const ids = {};
                for (const f of text.split("\n")) {
                    const m = f.match(/^wallhaven-([a-zA-Z0-9]+)\./);
                    if (m)
                        ids[m[1]] = true;
                }
                root.local = ids;
            }
        }
    }
}
