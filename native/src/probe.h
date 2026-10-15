#pragma once

#include <QGuiApplication>
#include <functional>
#include <QObject>
#include <QWindow>
#include <QColor>
#include <QQuickItem>
#include <QQuickWindow>
#include <QQmlContext>
#include <QtQml/qqml.h>
#include <QtQml/qqmlregistration.h>
#include <qpa/qwindowsysteminterface.h>
#include <private/qquickwindow_p.h>
#include <private/qquickitem_p.h>
#include <private/qquickshadereffectsource_p.h>
#include <QFile>
#include <QTextStream>

// Measuring without hands (IPC shell pointer): pointer events handed to one
// of the shell's windows as if the compositor had sent them, so hovers,
// presses and hover switches can be exercised and measured while nobody is
// at the machine. The real cursor doesn't move.
class Probe : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    using QObject::QObject;

    // The shell's windows: "<index> <class> <w>x<h> <title>" per line.
    Q_INVOKABLE QString windows() const {
        QString out;
        const auto all = QGuiApplication::topLevelWindows();
        for (int i = 0; i < all.size(); i++)
            out += QStringLiteral("%1 %2 %3x%4 visible=%5 %6\n").arg(i).arg(QLatin1String(all[i]->metaObject()->className())).arg(all[i]->width()).arg(all[i]->height()).arg(all[i]->isVisible()).arg(all[i]->title());
        return out;
    }

    // The visible items under (x, y) in a window, topmost last: type, file,
    // and `hovered` / `pressed` where they have them.
    Q_INVOKABLE QString itemsAt(int window, qreal x, qreal y) const {
        const auto all = QGuiApplication::topLevelWindows();
        auto *qw = window >= 0 && window < all.size() ? qobject_cast<QQuickWindow *>(all[window]) : nullptr;
        if (!qw)
            return QStringLiteral("no such window");
        QString out;
        std::function<void(QQuickItem *, int)> walk = [&](QQuickItem *it, int depth) {
            if (!it->isVisible() || it->opacity() <= 0)
                return;
            const QPointF p = it->mapFromScene(QPointF(x, y));
            if (!it->contains(p) && it->clip())
                return;
            if (it->contains(p)) {
                QString t = QString::fromLatin1(it->metaObject()->className());
                const int q = t.indexOf(QLatin1String("_QML"));
                if (q > 0)
                    t.truncate(q);
                QString file = qmlContext(it) ? qmlContext(it)->baseUrl().fileName() : QString();
                QVariant h = it->property("hovered"), pr = it->property("pressed");
                out += QString(depth, QLatin1Char(' ')) + t + QLatin1Char(' ') + file + (h.isValid() ? QStringLiteral(" hovered=%1").arg(h.toBool()) : QString()) + (pr.isValid() ? QStringLiteral(" pressed=%1").arg(pr.toBool()) : QString())
                    + QStringLiteral(" [%1,%2 %3x%4 op=%5 sc=%6%7]").arg(it->x()).arg(it->y()).arg(it->width()).arg(it->height()).arg(it->opacity()).arg(it->scale()).arg(it->property("color").isValid() ? QStringLiteral(" c=") + it->property("color").value<QColor>().name(QColor::HexArgb) : QString()) + QLatin1Char('\n');
            }
            for (QQuickItem *c : it->childItems())
                walk(c, depth + 1);
        };
        walk(qw->contentItem(), 0);
        return out;
    }

    // For `frames` scene frames of a window: which items are dirty when
    // each is synced (what makes it draw), written to `path`.
    Q_INVOKABLE void dirtyLog(int window, int frames, const QString &path) {
        const auto all = QGuiApplication::topLevelWindows();
        auto *qw = window >= 0 && window < all.size() ? qobject_cast<QQuickWindow *>(all[window]) : nullptr;
        if (!qw)
            return;
        auto *file = new QFile(path);
        file->open(QIODevice::WriteOnly | QIODevice::Truncate);
        auto left = std::make_shared<int>(frames);
        auto conn = std::make_shared<QMetaObject::Connection>();
        *conn = connect(qw, &QQuickWindow::beforeSynchronizing, qw, [qw, file, left, conn]() {
            QTextStream out(file);
            out << "frame\n";
            for (QQuickItem *it = QQuickWindowPrivate::get(qw)->dirtyItemList; it; it = QQuickItemPrivate::get(it)->nextDirtyItem) {
                QString t = QString::fromLatin1(it->metaObject()->className());
                const int q = t.indexOf(QLatin1String("_QML"));
                if (q > 0) t.truncate(q);
                const QString f = qmlContext(it) ? qmlContext(it)->baseUrl().fileName() : QString();
                if (auto *ses = qobject_cast<QQuickShaderEffectSource *>(it); ses && ses->sourceItem()) {
                    QQuickItem *src = ses->sourceItem();
                    QString st = QString::fromLatin1(src->metaObject()->className());
                    const int sq = st.indexOf(QLatin1String("_QML"));
                    if (sq > 0) st.truncate(sq);
                    out << "  (capturing " << st << ' ' << (qmlContext(src) ? qmlContext(src)->baseUrl().fileName() : QString()) << " parent " << (src->parentItem() && qmlContext(src->parentItem()) ? qmlContext(src->parentItem())->baseUrl().fileName() : QString()) << ")";
                }
                out << "  " << t << ' ' << f << " dirty=" << Qt::hex << QQuickItemPrivate::get(it)->dirtyAttributes << Qt::dec << '\n';
            }
            if (--*left <= 0) {
                QObject::disconnect(*conn);
                file->close();
                file->deleteLater();
            }
        }, Qt::DirectConnection);
    }

    // action: enter | move | press | release | leave (left button), at
    // (x, y) in the window.
    Q_INVOKABLE void pointer(int window, const QString &action, qreal x, qreal y) const {
        const auto all = QGuiApplication::topLevelWindows();
        if (window < 0 || window >= all.size())
            return;
        QWindow *w = all[window];
        const QPointF local(x, y);
        const QPointF global = w->mapToGlobal(local);
        if (action == QLatin1String("enter")) {
            QWindowSystemInterface::handleEnterEvent(w, local, global);
        } else if (action == QLatin1String("leave")) {
            QWindowSystemInterface::handleLeaveEvent(w);
        } else if (action == QLatin1String("press")) {
            QWindowSystemInterface::handleMouseEvent(w, local, global, Qt::LeftButton, Qt::LeftButton, QEvent::MouseButtonPress);
        } else if (action == QLatin1String("release")) {
            QWindowSystemInterface::handleMouseEvent(w, local, global, Qt::NoButton, Qt::LeftButton, QEvent::MouseButtonRelease);
        } else {
            QWindowSystemInterface::handleMouseEvent(w, local, global, Qt::NoButton, Qt::NoButton, QEvent::MouseMove);
        }
    }
};
