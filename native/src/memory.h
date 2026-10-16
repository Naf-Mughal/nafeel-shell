#pragma once

#include <QObject>
#include <QtQml/qqmlregistration.h>

#include <QFile>
#include <QGuiApplication>
#include <QHash>
#include <QQmlContext>
#include <QQuickItem>
#include <QQuickWindow>
#include <private/qquickitem_p.h>
#include <QtQml/qqml.h>

#include <algorithm>
#include <functional>
#include <QTextStream>
#include <dlfcn.h>
#include <malloc.h>
#include <sys/mman.h>
#include <thread>

// Hands memory the shell has freed back to the system. glibc keeps what's
// freed in its arenas (one per thread that allocated): a live wallpaper's
// decoder let go of tens of MB that stayed counted against the shell until
// something reused them. malloc_trim walks every arena; it runs on a thread
// of its own (it takes each arena's lock and madvises, a few ms) so the GUI
// thread never waits for it.
class Memory : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    using QObject::QObject;

    Q_INVOKABLE void trim() const {
        std::thread([] { malloc_trim(0); }).detach();
    }

    // Hands the idle file-backed pages (libraries, fonts: ~190 MB of the
    // shell's resident set had not been touched in a minute) back to the page
    // cache, where they stay for anyone who needs them and come back by a
    // minor fault when the shell does. Aged in two steps: the first call
    // clears the referenced bits (/proc/self/clear_refs); a later one drops
    // the mappings that nothing touched since. Only read-only mappings of
    // regular files with no copy-on-write page (no Anonymous, no dirty page:
    // relocated data would be lost) are dropped (MADV_DONTNEED); a mapping
    // whose pages were mostly touched is left. Off the GUI thread. The
    // system's real memory use doesn't change: the page cache keeps them.
    Q_INVOKABLE void trimFiles() const {
        std::thread([] {
            static bool aged = false;
            struct Map { unsigned long start = 0, end = 0; bool ok = false; long rss = 0, ref = 0; };
            QFile f(QStringLiteral("/proc/self/smaps"));
            if (!f.open(QIODevice::ReadOnly))
                return;
            QList<Map> maps;
            Map cur;
            bool have = false;
            long anon = 0, dirty = 0;
            auto finish = [&] {
                if (have && cur.ok && anon == 0 && dirty == 0 && cur.rss >= 64)
                    maps.append(cur);
            };
            const QByteArray all = f.readAll();
            for (const QByteArray &line : all.split('\n')) {
                if (!line.isEmpty() && ((line[0] >= '0' && line[0] <= '9') || (line[0] >= 'a' && line[0] <= 'f')) && line.contains('-') && line.indexOf(' ') > 0 && line.indexOf(':') > line.indexOf(' ')) {
                    // A header: start-end perms offset dev inode name
                    finish();
                    cur = Map();
                    anon = dirty = 0;
                    have = true;
                    const QList<QByteArray> parts = line.split(' ');
                    const QList<QByteArray> range = parts[0].split('-');
                    cur.start = range[0].toULong(nullptr, 16);
                    cur.end = range[1].toULong(nullptr, 16);
                    const QByteArray perms = parts.value(1);
                    const QByteArray name = line.mid(line.indexOf('/'));
                    // Read-only, not shared-writable, a regular file by path.
                    cur.ok = perms.size() >= 4 && perms[1] != 'w' && line.contains('/') && !name.contains("(deleted)") && !name.startsWith("/dev/") && !name.startsWith("/memfd") && !name.startsWith("/SYSV") && !name.startsWith("/proc/") && !name.startsWith("/run/") && !name.startsWith("/tmp/");
                    continue;
                }
                if (line.startsWith("Rss:"))
                    cur.rss = line.mid(4).trimmed().split(' ')[0].toLong();
                else if (line.startsWith("Referenced:"))
                    cur.ref = line.mid(11).trimmed().split(' ')[0].toLong();
                else if (line.startsWith("Anonymous:"))
                    anon = line.mid(10).trimmed().split(' ')[0].toLong();
                else if (line.startsWith("Private_Dirty:") || line.startsWith("Shared_Dirty:"))
                    dirty += line.mid(line.indexOf(':') + 1).trimmed().split(' ')[0].toLong();
            }
            finish();
            long droppedKb = 0, keptKb = 0;
            int n = 0;
            if (aged) {
                for (const Map &m : std::as_const(maps)) {
                    // Cold: under a quarter of what's resident was touched.
                    if (m.ref * 4 < m.rss) {
                        if (madvise(reinterpret_cast<void *>(m.start), m.end - m.start, MADV_DONTNEED) == 0) {
                            droppedKb += m.rss;
                            n++;
                        }
                    } else {
                        keptKb += m.rss;
                    }
                }
            }
            // Start the next aging window.
            if (FILE *c = fopen("/proc/self/clear_refs", "w")) {
                fputs("1", c);
                fclose(c);
            }
            if (aged)
                qInfo("memory: file pages handed back: %ld MB from %d mappings (%ld MB kept: touched lately)", droppedKb / 1024, n, keptKb / 1024);
            aged = true;
        }).detach();
    }

    // Measuring: jemalloc's own counters, in MB: `allocated` is what the
    // program holds (live objects), `active` the pages those sit in,
    // `resident` what the allocator keeps mapped, `retained` what it keeps
    // for reuse. Allocated is the number to compare a change by: it moves
    // with the code, not with fragmentation or what else is mapped.
    Q_INVOKABLE QString stats() const {
        using mallctl_t = int (*)(const char *, void *, size_t *, void *, size_t);
        static auto fn = reinterpret_cast<mallctl_t>(dlsym(RTLD_DEFAULT, "mallctl"));
        if (!fn)
            return QStringLiteral("{}");
        uint64_t epoch = 1;
        size_t sz = sizeof(epoch);
        fn("epoch", &epoch, &sz, &epoch, sz);
        auto get = [&](const char *name) {
            size_t v = 0, n = sizeof(v);
            fn(name, &v, &n, nullptr, 0);
            return double(v) / 1048576.0;
        };
        return QStringLiteral("{\"allocated\":%1,\"active\":%2,\"resident\":%3,\"retained\":%4}")
            .arg(get("stats.allocated"), 0, 'f', 1)
            .arg(get("stats.active"), 0, 'f', 1)
            .arg(get("stats.resident"), 0, 'f', 1)
            .arg(get("stats.retained"), 0, 'f', 1);
    }

    // Measuring: a jemalloc heap profile of what's live now (needs the shell
    // started with MALLOC_CONF=prof:true; read it with jeprof).
    Q_INVOKABLE void heapDump(const QString &path) const {
        using mallctl_t = int (*)(const char *, void *, size_t *, void *, size_t);
        static auto fn = reinterpret_cast<mallctl_t>(dlsym(RTLD_DEFAULT, "mallctl"));
        if (!fn) return;
        QByteArray p = path.toLocal8Bit();
        const char *cp = p.constData();
        fn("prof.dump", nullptr, nullptr, &cp, sizeof(cp));
    }

    // Measuring (IPC shell census): every live object under the shell's
    // windows, counted by type and by the file that declares it, written to
    // `path`. What the warm shell is made of, to find what costs memory.
    Q_INVOKABLE void census(const QString &path) const {
        QHash<QString, int> byType, byFile, images, offscreen;
        int offscreenKb = 0;
        QHash<const QObject *, bool> seen;
        int total = 0, items = 0, layers = 0;
        std::function<void(QObject *)> walk = [&](QObject *o) {
            if (!o || seen.contains(o)) return;
            seen.insert(o, true);
            total++;
            QString t = QString::fromLatin1(o->metaObject()->className());
            const int q = t.indexOf(QLatin1String("_QML"));
            if (q > 0) t.truncate(q);
            byType[t]++;
            if (auto *ctx = qmlContext(o)) byFile[ctx->baseUrl().fileName()]++;
            for (QObject *c : o->children()) walk(c);
            if (o->inherits("QQuickImageBase")) {
                const QSize ps = o->property("paintedWidth").isValid() ? QSize() : QSize();
                Q_UNUSED(ps);
                const QSize src = o->property("sourceSize").toSize();
                const QString u = o->property("source").toUrl().toString();
                const bool vis = static_cast<QQuickItem *>(o)->isVisible();
                images[u + QLatin1String(" ") + QString::number(src.width()) + QLatin1Char('x') + QString::number(src.height()) + (vis ? QString() : QLatin1String(" hidden"))]++;
            }
            if (auto *it = qobject_cast<QQuickItem *>(o)) {
                items++;
                const QString where = qmlContext(it) ? qmlContext(it)->baseUrl().fileName() : QStringLiteral("?");
                auto line = [&](const char *kind, QSizeF sz) {
                    // Not visible anywhere up the tree: its texture may still be held.
                    bool shown = it->isVisible() && it->window() && it->window()->isVisible();
                    offscreen[QStringLiteral("%1 %2 %3x%4%5").arg(QLatin1String(kind), where).arg(int(sz.width())).arg(int(sz.height())).arg(shown ? QString() : QStringLiteral(" hidden"))]++;
                    offscreenKb += int(sz.width() * sz.height() * 4 / 1024);
                };
                if (auto *d = QQuickItemPrivate::get(it); d->extra.isAllocated() && d->extra->layer && d->extra->layer->enabled()) {
                    layers++;
                    QSize ts = d->extra->layer->size();
                    line("layer", ts.isEmpty() ? QSizeF(it->width(), it->height()) : QSizeF(ts));
                }
                if (o->inherits("QQuickShaderEffectSource")) {
                    QSize ts = o->property("textureSize").toSize();
                    QQuickItem *src = qvariant_cast<QQuickItem *>(o->property("sourceItem"));
                    line(o->property("live").toBool() ? "ses-live" : "ses", ts.isEmpty() && src ? QSizeF(src->width(), src->height()) : QSizeF(ts));
                }
                for (QQuickItem *c : it->childItems()) walk(c);
            }
        };
        for (QWindow *w : QGuiApplication::allWindows()) {
            walk(w);
            if (auto *qw = qobject_cast<QQuickWindow *>(w)) walk(qw->contentItem());
        }
        auto dump = [](const QHash<QString, int> &h, QTextStream &out) {
            QList<std::pair<int, QString>> v;
            for (auto it = h.begin(); it != h.end(); ++it) v.append({it.value(), it.key()});
            std::sort(v.begin(), v.end(), [](auto &a, auto &b) { return a.first > b.first; });
            for (int i = 0; i < v.size() && i < 150; i++) out << v[i].first << '\t' << v[i].second << '\n';
        };
        QFile f(path);
        if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) return;
        QTextStream out(&f);
        out << "objects " << total << " items " << items << " layers " << layers << " windows " << QGuiApplication::allWindows().size() << "\n";
        out << "== by type\n";
        dump(byType, out);
        out << "== by file\n";
        dump(byFile, out);
        out << "== offscreen (kind file size), ~" << offscreenKb / 1024 << " MB if all held\n";
        dump(offscreen, out);
        out << "== images (source sourceSize)\n";
        dump(images, out);
    }
};
