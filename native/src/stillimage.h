#pragma once

#include <QHash>
#include <QJSValue>
#include <QMutex>
#include <QQuickAsyncImageProvider>
#include <QQuickItem>
#include <QtQml/qqmlregistration.h>
#include <QQuickTextureFactory>
#include <QThreadPool>

// "image://still/<fit|crop>/<path>": a picture that lives only on the GPU.
//
// Qt keeps every Image's decoded picture in memory next to its texture, for
// as long as the Image exists: the shell's warm panels held ~40 MB of
// wallpaper thumbnails and covers that were already on the GPU. A still is
// decoded off the GUI thread at the size asked for (sourceSize; "fit" keeps
// it inside, "crop" covers it, never larger than the file), and its picture
// is let go once it has become a texture. If a texture is needed again (a
// second window, a scene graph rebuilt) the file is read again, there and
// then: rare, and a few ms.
class StillProvider : public QQuickAsyncImageProvider {
public:
    StillProvider();
    QQuickImageResponse *requestImageResponse(const QString &id, const QSize &requestedSize) override;

    // Decode `path` for `requested` (see above).
    static QImage load(const QString &path, QSize requested, bool crop);

    // "image://still/mem/<key>": a picture in memory (StillGrab), taken out
    // of here by the one Image that shows it, and gone once on the GPU.
    static void put(const QString &key, const QImage &image);
    static QImage take(const QString &key);

private:
    QThreadPool m_pool;
};

class StillTexture : public QQuickTextureFactory {
public:
    StillTexture(QImage image, QString path, QSize requested, bool crop);

    QSGTexture *createTexture(QQuickWindow *window) const override;
    QSize textureSize() const override { return m_size; }
    int textureByteCount() const override { return m_size.width() * m_size.height() * 4; }
    QImage image() const override;

private:
    mutable QImage m_image;
    QString m_path;
    QSize m_requested;
    bool m_crop;
    QSize m_size;
};

// A picture of an item (a screen's capture) as image://still/mem/…: one
// copy, let go once it's a texture. Item.grabToImage keeps two (the result
// and the URL's converted copy) until the JS engine collects the result:
// the lock screen's capture of the desktop held 16 MB for the whole lock.
//
//   StillGrab.grab(item, "screen-eDP-1", url => shot = url)
class StillGrab : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    using QObject::QObject;
    Q_INVOKABLE void grab(QQuickItem *item, const QString &key, const QJSValue &done);
};
