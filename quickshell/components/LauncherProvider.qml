import QtQuick

// One source of the launcher's results (services/Launcher.qml), declared by a
// plugin ("providers" in its plugin.json). It answers a query with results:
//
//   { title, subtitle,
//     icon: a Material Symbol, or image: an icon theme name / file url,
//     or glyph: text drawn large in the icon's place (an emoji),
//     score: how well it matches (Fuzzy's scale; 0 = no match),
//     key: a stable id, for ranking what's picked often and lately,
//     run(): what Enter does,
//     actions: [{ label, icon, run() }]   Tab lists them, Shift+Enter runs
//                                          the first,
//     confirm: "Shut down"                 a first Enter asks, a second runs,
//     keepOpen: true                       the command center stays open,
//     highlight: false                     no match highlighting in title,
//     top: true                            above any fuzzy match (asked for),
//     idle: N                              its place when nothing's typed
//                                          (default: how much it's used) }
//
// Synchronous: return them from query(). Asynchronous (a process, the
// network): return null and publish(seq, results) when they're ready, for
// the query that came with `seq` (a later query has a later seq; stale
// answers are dropped).
QtObject {
    id: root

    // Its name in the results, and its keyword: "f report" asks only this
    // provider; a symbol (">", "=") needs no space after it.
    property string name
    // Filter prefixes it claims ("pdf" for "pdf: budget": the search is
    // scoped to it, and Launcher.filter says which).
    property var prefixes: []
    // The search bar's icon while the search is scoped to it.
    property string icon: "search"
    property string keyword
    // Answers queries without its keyword too, merged with the others.
    property bool global: true
    // Its results' scores are multiplied by this (how much it's usually
    // what's wanted).
    property real weight: 1
    // At most this many results from it.
    property int limit: 30
    // An asynchronous provider's last answer stays up until the next comes
    // (no flicker); off where an old answer would mislead (the calculator).
    property bool keepStale: true
    // Answers the empty query (shown when nothing's typed, ranked by use).
    property bool answersEmpty: false

    signal published(int seq, var results)

    function query(text: string, seq: int): var {
        return [];
    }

    function publish(seq: int, results: var): void {
        published(seq, results);
    }
}
