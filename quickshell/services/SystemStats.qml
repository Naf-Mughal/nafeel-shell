pragma Singleton

// CPU, memory, temperature, GPU, storage and network, read from /proc and
// sysfs every 2 s while anything shows them (`watchers`; sampling is the only
// way to get rates and loads, so nothing runs while nobody looks).

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int watchers: 0
    property real cpu: 0
    property real memUsed: 0 // bytes
    property real memTotal: 0
    property real temp: 0 // °C
    readonly property real mem: memTotal > 0 ? memUsed / memTotal : 0
    property real swapUsed: 0
    property real swapTotal: 0
    // GPU busy (amdgpu's gpu_busy_percent), -1 if there's none to read.
    property real gpu: -1
    property real gpuTemp: 0
    // The processor's and graphics' names (read once).
    property string cpuName: ""
    property string gpuName: ""
    // The root filesystem (bytes).
    property real diskUsed: 0
    property real diskTotal: 0
    readonly property real disk: diskTotal > 0 ? diskUsed / diskTotal : 0
    // Every physical drive: [{ name, model, used, total, mounts }] (the used
    // and total of its mounted file systems; swap and loop devices left out).
    property var disks: []
    // Network, all interfaces but lo: bytes per second, and the totals.
    property real rx: 0
    property real tx: 0
    property real rxTotal: 0
    property real txTotal: 0
    property var lastNet: null
    // Recent history for sparklines (the last 60 samples, 0..1 / B/s).
    property var cpuHistory: []
    property var rxHistory: []
    property var txHistory: []

    function _push(list: var, v: real): var {
        return [...list.slice(-59), v];
    }

    function bytes(b: real): string {
        const u = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (b >= 1024 && i < u.length - 1) {
            b /= 1024;
            i++;
        }
        return `${b.toFixed(b >= 100 || i === 0 ? 0 : 1)} ${u[i]}`;
    }

    property var lastCpu: null

    Timer {
        running: root.watchers > 0
        interval: 2000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
            netdev.reload();
            thermal.running = true;
            extra.running = true;
            drives.running = true;
        }
    }

    FileView {
        id: stat

        path: "/proc/stat"
        onLoaded: {
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + (f[4] ?? 0), total = f.reduce((a, b) => a + b, 0);
            if (root.lastCpu) {
                const dt = total - root.lastCpu.total;
                root.cpu = dt > 0 ? 1 - (idle - root.lastCpu.idle) / dt : 0;
            }
            root.cpuHistory = root._push(root.cpuHistory, root.cpu);
            root.lastCpu = {
                idle: idle,
                total: total
            };
        }
    }

    FileView {
        id: meminfo

        path: "/proc/meminfo"
        onLoaded: {
            const get = k => Number((text().match(new RegExp(`^${k}:\\s+(\\d+)`, "m")) ?? [0, 0])[1]) * 1024;
            root.memTotal = get("MemTotal");
            root.memUsed = root.memTotal - get("MemAvailable");
            root.swapTotal = get("SwapTotal");
            root.swapUsed = root.swapTotal - get("SwapFree");
        }
    }

    FileView {
        id: netdev

        path: "/proc/net/dev"
        onLoaded: {
            let rx = 0, tx = 0;
            for (const line of text().split("\n").slice(2)) {
                const m = line.trim().match(/^([^:]+):\s*(.*)$/);
                if (!m || m[1] === "lo")
                    continue;
                const f = m[2].split(/\s+/).map(Number);
                rx += f[0];
                tx += f[8];
            }
            const now = Date.now();
            if (root.lastNet) {
                const dt = (now - root.lastNet.t) / 1000;
                if (dt > 0) {
                    root.rx = Math.max(0, (rx - root.lastNet.rx) / dt);
                    root.tx = Math.max(0, (tx - root.lastNet.tx) / dt);
                    root.rxHistory = root._push(root.rxHistory, root.rx);
                    root.txHistory = root._push(root.txHistory, root.tx);
                }
            }
            root.rxTotal = rx;
            root.txTotal = tx;
            root.lastNet = {
                rx,
                tx,
                t: now
            };
        }
    }

    Process {
        id: drives

        command: ["lsblk", "-b", "-J", "-o", "NAME,TYPE,SIZE,MODEL,MOUNTPOINTS,FSUSED,FSSIZE"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const out = [];
                    for (const d of JSON.parse(text).blockdevices ?? []) {
                        if (d.type !== "disk" || /^(zram|loop|ram)/.test(d.name))
                            continue;
                        let used = 0, total = 0;
                        const mounts = [];
                        const walk = n => {
                            const mp = (n.mountpoints ?? []).filter(m => m && m !== "[SWAP]");
                            if (mp.length && n.fssize) {
                                used += Number(n.fsused) || 0;
                                total += Number(n.fssize) || 0;
                                mounts.push(mp.includes("/") ? "/" : mp[0]);
                            }
                            for (const c of n.children ?? [])
                                walk(c);
                        };
                        walk(d);
                        out.push({
                            name: d.name,
                            model: (d.model ?? d.name).trim(),
                            used,
                            total: total || Number(d.size) || 0,
                            mounts
                        });
                    }
                    // The system drive first.
                    root.disks = out.sort((a, b) => b.mounts.includes("/") - a.mounts.includes("/"));
                } catch (e) {}
            }
        }
    }

    // GPU busy and the root filesystem.
    Process {
        id: extra

        command: ["sh", "-c", 'g=-1; for f in /sys/class/drm/card*/device/gpu_busy_percent; do [ -r "$f" ] && { g=$(cat "$f"); break; }; done; echo "$g"; df -B1 --output=used,size / | tail -1; t=0; for h in /sys/class/hwmon/hwmon*; do case "$(cat "$h/name")" in amdgpu|nouveau|i915|xe) t=$(cat "$h/temp1_input" 2>/dev/null); break;; esac; done; echo "${t:-0}"']
        stdout: StdioCollector {
            onStreamFinished: {
                const [g, d, gt] = text.trim().split("\n");
                root.gpuTemp = (parseInt(gt) || 0) / 1000;
                const gv = parseInt(g);
                root.gpu = isNaN(gv) || gv < 0 ? -1 : gv / 100;
                const [used, size] = (d ?? "").trim().split(/\s+/).map(Number);
                root.diskUsed = used || 0;
                root.diskTotal = size || 0;
            }
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//; s/ with Radeon.*//; s/(R)//g; s/(TM)//g'; lspci -mm 2>/dev/null | grep -iE 'VGA|3D|Display' | head -1 | awk -F'\\\"' '{print $6}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [cpu, gpu] = text.trim().split("\n");
                root.cpuName = (cpu ?? "").trim();
                root.gpuName = (gpu ?? "").replace(/\[|\]/g, "").trim();
            }
        }
    }

    // The CPU's own sensor (k10temp on AMD, coretemp on Intel), else the
    // hottest thermal zone.
    Process {
        id: thermal

        command: ["sh", "-c", 'for h in /sys/class/hwmon/hwmon*; do case "$(cat "$h/name")" in k10temp|coretemp|zenpower) cat "$h/temp1_input"; exit;; esac; done; cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1']
        stdout: StdioCollector {
            onStreamFinished: root.temp = (parseInt(text) || 0) / 1000
        }
    }
}
