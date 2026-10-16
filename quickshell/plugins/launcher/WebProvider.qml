import QtQuick
import Quickshell
import Nafeel
import qs.components
import qs.services

// The web: a URL typed opens in the browser; a keyword and a query ("yt
// lofi", "gh quickshell") opens that site's search; anything else offers a
// Google search, always last in the list. Keywords are below; more can be
// added with the launcher.webSearches setting.
LauncherProvider {
    id: root

    name: "Web"
    icon: "language"
    keyword: "g"
    weight: 0.5
    limit: 6

    // The built-in ones, then the user's (Settings: Launcher, Web keywords).
    readonly property var sites: Object.assign({}, builtin, Plugins.instance("launcher")?.webKeywords ?? {})

    // keyword -> [label, icon, url with %s]
    readonly property var builtin: ({
            g: ["Google", "search", "https://www.google.com/search?q=%s"],
            yt: ["YouTube", "smart_display", "https://www.youtube.com/results?search_query=%s"],
            gh: ["GitHub", "code", "https://github.com/search?q=%s"],
            maps: ["Google Maps", "map", "https://www.google.com/maps/search/%s"],
            wiki: ["Wikipedia", "menu_book", "https://en.wikipedia.org/w/index.php?search=%s"],
            aur: ["AUR", "package_2", "https://aur.archlinux.org/packages?K=%s"],
            arch: ["Arch Wiki", "menu_book", "https://wiki.archlinux.org/index.php?search=%s"],
            npm: ["npm", "deployed_code", "https://www.npmjs.com/search?q=%s"],
            mdn: ["MDN", "menu_book", "https://developer.mozilla.org/en-US/search?q=%s"],
            so: ["Stack Overflow", "forum", "https://stackoverflow.com/search?q=%s"],
            tr: ["Translate", "translate", "https://translate.google.com/?sl=auto&text=%s"],
            img: ["Google Images", "image", "https://www.google.com/search?tbm=isch&q=%s"]
        })

    function open(url: string): void {
        Quickshell.execDetached(["xdg-open", url]);
    }

    function entry(label: string, icon: string, url: string, title: string, score: real, sub: string): var {
        return {
            top: score >= 100,
            title: title,
            subtitle: sub,
            icon: icon,
            score: score,
            key: "",
            highlight: false,
            run: () => open(url),
            actions: [
                {
                    label: "Copy the link",
                    icon: "link",
                    run: () => Clipboard.copyText(url)
                }
            ]
        };
    }

    // Looks like an address: a scheme, or a dotted host without spaces.
    function asUrl(t: string): string {
        if (/\s/.test(t))
            return "";
        if (/^https?:\/\/\S+$/i.test(t))
            return t;
        if (/^(www\.)?[a-z0-9-]+(\.[a-z0-9-]+)*\.(com|org|net|io|dev|app|co|pk|me|ai|gg|tv|xyz|edu|gov|in|uk|de|fr|info)(\/\S*)?$/i.test(t))
            return "https://" + t;
        return "";
    }

    function query(text: string, seq: int): var {
        const out = [];
        const scoped = Launcher.scope === root;
        // Typed after "g ": that's a Google search; elsewhere, a keyword
        // first ("yt lofi").
        let site = null, q = text;
        const m = /^(\S+)\s+(.+)$/.exec(text);
        if (!scoped && m && sites[m[1]]) {
            site = sites[m[1]];
            q = m[2];
        }
        if (text === "")
            return [];
        const url = asUrl(text);
        if (url)
            out.push(entry("", "language", url, text, 160, "Open in the browser"));
        if (site)
            out.push(entry(site[0], site[1], site[2].replace("%s", encodeURIComponent(q)), `${site[0]}: ${q}`, 140, "Search " + site[0]));
        else if (!scoped && text.length < 2)
            return out;
        // Always offered: Google, below real matches.
        out.push(entry("Google", "search", sites.g[2].replace("%s", encodeURIComponent(q)), `Search Google for “${q}”`, site ? 20 : 22, "Open in the browser"));
        return out;
    }
}
