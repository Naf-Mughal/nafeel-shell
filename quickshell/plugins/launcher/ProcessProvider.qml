import QtQuick
import Quickshell
import Quickshell.Io
import Nafeel
import qs.components
import qs.services

// Your processes, to stop: "kill chrome". Grouped by name (a browser is a
// dozen of them), busiest first when empty. Enter asks twice, then ends them
// all politely (SIGTERM); Tab: only the busiest one, or force kill (SIGKILL).
LauncherProvider {
    id: root

    name: "Processes"
    icon: "dangerous"
    keyword: "kill"
    global: false
    answersEmpty: true
    limit: 30

    property string asked: ""
    property int askedSeq: -1

    function query(text: string, seq: int): var {
        asked = text;
        askedSeq = seq;
        if (!ps.running)
            ps.running = true;
        return null;
    }

    readonly property Process lister: Process {
        id: ps

        command: ["ps", "-u", Quickshell.env("USER"), "-o", "pid=,pcpu=,rss=,comm=,args=", "--sort=-pcpu"]
        stdout: StdioCollector {
            onStreamFinished: root.publishFrom(root.askedSeq, root.asked, text)
        }
    }

    function publishFrom(seq: int, text: string, out: string): void {
        const rows = [];
        for (const line of out.split("\n")) {
            const m = /^\s*(\d+)\s+([\d.]+)\s+(\d+)\s+(\S+)\s*(.*)$/.exec(line);
            if (!m || m[4] === "ps" || m[4] === "sh" && /ps -u/.test(m[5]))
                continue;
            rows.push({ pid: m[1], cpu: parseFloat(m[2]), mb: Math.round(parseInt(m[3]) / 1024), comm: m[4], args: m[5] });
        }
        // By name, the busiest process leading.
        const groups = new Map();
        for (const r of rows) {
            const g = groups.get(r.comm) ?? { comm: r.comm, top: r, pids: [], cpu: 0, mb: 0 };
            g.pids.push(r.pid);
            g.cpu += r.cpu;
            g.mb += r.mb;
            if (r.cpu > g.top.cpu)
                g.top = r;
            groups.set(r.comm, g);
        }
        const list = [...groups.values()];
        const out2 = [];
        const names = text === "" ? null : Fuzzy.scores(list.map(g => g.comm), text);
        const scores = text === "" ? null : Fuzzy.scores(list.map(g => `${g.comm} ${g.top.args}`), text);
        list.forEach((g, i) => {
            const s = text === "" ? Math.min(100, 20 + g.cpu * 4 + g.mb / 40) : Math.max(names[i] * 1.2, scores[i] * 0.7);
            if (s <= 0)
                return;
            const many = g.pids.length > 1;
            out2.push({
                title: g.comm,
                subtitle: `${many ? g.pids.length + " processes" : "pid " + g.top.pid}   ·   ${g.cpu.toFixed(1)}% CPU   ·   ${g.mb} MB   ·   ${g.top.args.slice(0, 80)}`,
                icon: "dangerous",
                score: s,
                key: "",
                confirm: many ? `End all ${g.comm}` : "End " + g.comm,
                run: () => Quickshell.execDetached(["kill", ...g.pids]),
                actions: (many ? [
                        {
                            label: `End only the busiest (pid ${g.top.pid})`,
                            icon: "target",
                            run: () => Quickshell.execDetached(["kill", g.top.pid])
                        }
                    ] : []).concat([
                        {
                            label: many ? "Force kill all (SIGKILL)" : "Force kill (SIGKILL)",
                            icon: "dangerous",
                            run: () => Quickshell.execDetached(["kill", "-9", ...g.pids])
                        },
                        {
                            label: "Copy the process id",
                            icon: "content_copy",
                            run: () => Clipboard.copyText(g.top.pid)
                        }
                    ])
            });
        });
        publish(seq, out2);
    }
}
