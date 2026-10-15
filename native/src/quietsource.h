#pragma once

#include <QObject>
#include <QPointer>
#include <memory>
#include <QQuickItem>
#include <QQuickWindow>
#include <QtQml/qqmlregistration.h>
#include <private/qquickshadereffectsource_p.h>
#include <private/qsgadaptationlayer_p.h>

// A capture (ShaderEffectSource, or an item's layer) that draws no frame of
// its own (QuietSource.quiet(item)).
//
// When what a capture shows changes, Qt's layer captures it in that very
// frame, and also asks its ShaderEffectSource for another (updateRequested),
// which draws the whole window again for nothing: a lock screen whose
// backdrop is captured redrew at 60 fps for a 30 fps change, every frame
// twice. Quiet, the capture is still taken in the frame where its source
// changed (the source's own update brings that frame); only the extra one
// is gone. For captures whose source changes with something else in the
// window (an animation, a video's frames), not for one asked to update on
// its own (scheduleUpdate on a still source).
class QuietSource : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    using QObject::QObject;

    // `item`: a ShaderEffectSource, or an item with layer.enabled.
    Q_INVOKABLE void quiet(QQuickItem *item) {
        QQuickShaderEffectSource *ses = qobject_cast<QQuickShaderEffectSource *>(item);
        if (!ses && item && item->parentItem()) {
            // A layer's capture: the ShaderEffectSource beside it whose
            // source it is.
            for (QQuickItem *c : item->parentItem()->childItems())
                if (auto *s = qobject_cast<QQuickShaderEffectSource *>(c); s && s->sourceItem() == item)
                    ses = s;
            if (!ses)
                for (QObject *c : item->parentItem()->children())
                    if (auto *s = qobject_cast<QQuickShaderEffectSource *>(c); s && s->sourceItem() == item)
                        ses = s;
        }
        if (!ses) {
            // A layer's capture is made once the item is in a window.
            if (item && !item->window()) {
                QPointer<QQuickItem> guard = item;
                auto *self = this;
                auto conn = std::make_shared<QMetaObject::Connection>();
                *conn = connect(item, &QQuickItem::windowChanged, this, [self, guard, conn](QQuickWindow *w) {
                    if (!w)
                        return;
                    QObject::disconnect(*conn);
                    QMetaObject::invokeMethod(self, [self, guard]() { if (guard) self->quiet(guard); }, Qt::QueuedConnection);
                });
            }
            return;
        }
        auto watch = [ses]() {
            QQuickWindow *w = ses->window();
            if (!w)
                return;
            // Its layer is made (and remade) on the render thread: let go of
            // the extra frame each time the scene is synced.
            QPointer<QQuickShaderEffectSource> guard = ses;
            QObject::connect(w, &QQuickWindow::afterSynchronizing, ses, [guard]() {
                if (!guard)
                    return;
                QSGTextureProvider *p = guard->textureProvider();
                auto *layer = p ? qobject_cast<QSGLayer *>(p->texture()) : nullptr;
                if (layer)
                    QObject::disconnect(layer, &QSGLayer::updateRequested, guard, nullptr);
            }, Qt::DirectConnection);
        };
        watch();
        connect(ses, &QQuickItem::windowChanged, ses, [watch](QQuickWindow *) { watch(); });
    }
};
