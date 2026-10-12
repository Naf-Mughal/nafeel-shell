pragma Singleton

// Synced lyrics for what's playing (Caelestia's lyrics, its lrclib path):
// asked of lrclib.net (an open lyrics database) by artist, title, album and
// length, then by a search if that misses; parsed from LRC into timed lines,
// and the line being sung follows the player. Cached per track in
// ~/.cache/nafeel-shell/lyrics, so a song is only looked up once.
//
//   lines    [{ t (seconds), text }]   ([] when none: `plain` may still hold
//                                      unsynced lyrics)
//   current  the index of the line being sung (-1 before the first)
//   state    "idle" | "loading" | "ready" | "none"

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    readonly property var player: Media.active
    readonly property string artist: player?.trackArtist ?? ""
    readonly property string title: player?.trackTitle ?? ""
    readonly property string album: player?.trackAlbum ?? ""
    readonly property real length: player?.length ?? 0
    readonly property string key: artist && title ? `${artist}|${title}` : ""
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/nafeel-shell/lyrics"

    property var lines: []
    property string plain: ""
    property string state: "idle"
    // Only fetches while something shows them (`watchers`).
    property int watchers: 0

    readonly property int current: {
        const pos = player?.position ?? 0;
        let i = -1;
        for (let k = 0; k < lines.length && lines[k].t <= pos + 0.15; k++)
            i = k;
        return i;
    }

    onKeyChanged: if (watchers > 0)
        load()
    onWatchersChanged: if (watchers > 0 && state === "idle")
        load()

    function _file(): string {
        return `${cacheDir}/${Qt.md5(key)}.json`;
    }

    function parse(lrc: string): var {
        const out = [];
        for (const line of (lrc ?? "").split("\n")) {
            // (No String.matchAll in Qt's JavaScript: an exec loop.)
            const re = /\[(\d+):(\d+(?:\.\d+)?)\]/g;
            const text = line.replace(/\[[^\]]*\]/g, "").trim();
            let m;
            while ((m = re.exec(line)) !== null)
                out.push({
                    t: parseInt(m[1]) * 60 + parseFloat(m[2]),
                    text
                });
        }
        return out.sort((a, b) => a.t - b.t);
    }

    function _use(result: var): void {
        lines = parse(result?.syncedLyrics ?? "");
        plain = result?.plainLyrics ?? "";
        state = lines.length > 0 || plain ? "ready" : "none";
    }

    function load(): void {
        lines = [];
        plain = "";
        if (!key) {
            state = "idle";
            return;
        }
        state = "loading";
        cached.path = "";
        cached.path = _file();
    }

    // The cache first.
    FileView {
        id: cached

        printErrors: false
        onLoaded: {
            try {
                root._use(JSON.parse(text()));
                return;
            } catch (e) {}
            root._fetch();
        }
        onLoadFailed: root._fetch()
    }

    function _fetch(): void {
        const q = s => encodeURIComponent(s);
        const get = `https://lrclib.net/api/get?artist_name=${q(artist)}&track_name=${q(title)}` + (album ? `&album_name=${q(album)}` : "") + (length > 0 ? `&duration=${Math.round(length)}` : "");
        const search = `https://lrclib.net/api/search?artist_name=${q(artist)}&track_name=${q(title)}`;
        fetcher.forKey = key;
        fetcher.command = ["sh", "-c", 'curl -fsS --max-time 12 -A "$3" "$1" || curl -fsS --max-time 12 -A "$3" "$2"', "sh", get, search, "nafeel-shell (lyrics)"];
        fetcher.running = true;
    }

    Process {
        id: fetcher

        property string forKey

        stdout: StdioCollector {
            onStreamFinished: {
                if (fetcher.forKey !== root.key)
                    return;
                let result = null;
                try {
                    const j = JSON.parse(text);
                    // /get answers one; /search a list: the first with synced
                    // lyrics, else the first.
                    result = Array.isArray(j) ? (j.find(r => r.syncedLyrics) ?? j[0] ?? null) : j;
                } catch (e) {}
                root._use(result);
                if (!result)
                    return;
                const keep = JSON.stringify({
                    syncedLyrics: result.syncedLyrics ?? "",
                    plainLyrics: result.plainLyrics ?? ""
                });
                saver.command = ["sh", "-c", 'mkdir -p "$1" && printf "%s" "$3" > "$2"', "sh", root.cacheDir, root._file(), keep];
                saver.running = true;
            }
        }
        onExited: code => {
            if (code !== 0 && fetcher.forKey === root.key)
                root.state = "none";
        }
    }

    Process {
        id: saver
    }
}
