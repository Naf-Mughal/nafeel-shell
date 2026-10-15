#pragma once

#include <QQuickAsyncImageProvider>
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
