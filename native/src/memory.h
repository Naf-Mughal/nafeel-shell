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
