#include "stillimage.h"

#include <QImageReader>
#include <QQuickItemGrabResult>
#include <QQuickWindow>
#include <QRunnable>
#include <QUrl>
#include <utility>

namespace {

class StillResponse : public QQuickImageResponse, public QRunnable {
public:
    StillResponse(QString path, QSize requested, bool crop)
        : m_path(std::move(path)), m_requested(requested), m_crop(crop) {
        setAutoDelete(false);
    }

    void run() override {
        QImage image = StillProvider::load(m_path, m_requested, m_crop);
        if (image.isNull())
            m_error = QStringLiteral("can't read %1").arg(m_path);
        else
            m_factory = new StillTexture(std::move(image), m_path, m_requested, m_crop);
        emit finished();
    }

    QQuickTextureFactory *textureFactory() const override {
        QQuickTextureFactory *f = m_factory;
        m_factory = nullptr;
        return f;
    }
    QString errorString() const override { return m_error; }

    ~StillResponse() override { delete m_factory; }

private:
    QString m_path;
    QSize m_requested;
    bool m_crop;
    mutable QQuickTextureFactory *m_factory = nullptr;
    QString m_error;
};

} // namespace

StillProvider::StillProvider() {
    // Off the GUI thread, a couple at a time (a panel's thumbnails at once).
    m_pool.setMaxThreadCount(2);
    m_pool.setExpiryTimeout(5000);
}

namespace {
QMutex g_memLock;
QHash<QString, QImage> g_mem;
int g_memSerial = 0;

// A picture already in memory: no decoding.
class MemResponse : public QQuickImageResponse {
public:
    explicit MemResponse(QImage image) {
        if (!image.isNull())
            m_factory = new StillTexture(std::move(image), QString(), QSize(), false);
        QMetaObject::invokeMethod(this, &QQuickImageResponse::finished, Qt::QueuedConnection);
    }
    ~MemResponse() override { delete m_factory; }
    QQuickTextureFactory *textureFactory() const override { return std::exchange(m_factory, nullptr); }
    QString errorString() const override { return m_factory ? QString() : QStringLiteral("no such picture"); }

private:
    mutable QQuickTextureFactory *m_factory = nullptr;
};
} // namespace

void StillProvider::put(const QString &key, const QImage &image) {
    QMutexLocker lock(&g_memLock);
    g_mem.insert(key, image);
}

QImage StillProvider::take(const QString &key) {
    QMutexLocker lock(&g_memLock);
    return g_mem.take(key);
}

void StillGrab::grab(QQuickItem *item, const QString &key, const QJSValue &done) {
    if (!item)
        return;
    QSharedPointer<QQuickItemGrabResult> result = item->grabToImage();
    if (!result)
        return;
    QJSValue cb = done;
    // The result kept only until it's ready; its image moved into the
    // provider (the one copy).
    connect(result.data(), &QQuickItemGrabResult::ready, this, [result, key, cb]() mutable {
        const QString id = key + QLatin1Char('-') + QString::number(++g_memSerial);
        StillProvider::put(id, result->image());
        result.reset();
        if (cb.isCallable())
            cb.call({QJSValue(QStringLiteral("image://still/mem/") + id)});
    });
}

QQuickImageResponse *StillProvider::requestImageResponse(const QString &id, const QSize &requestedSize) {
    if (id.startsWith(QLatin1String("mem/")))
        return new MemResponse(take(id.mid(4)));
    // id: "<fit|crop>/<path>" (the path percent-encoded or not).
    const int slash = id.indexOf(QLatin1Char('/'));
    const bool crop = id.left(slash) == QLatin1String("crop");
    QString path = QUrl::fromPercentEncoding(id.mid(slash + 1).toUtf8());
    if (path.startsWith(QLatin1String("file://")))
        path = QUrl(path).toLocalFile();
    if (!path.startsWith(QLatin1Char('/')))
        path.prepend(QLatin1Char('/'));
    auto *response = new StillResponse(path, requestedSize, crop);
    m_pool.start(response);
    return response;
}

QImage StillProvider::load(const QString &path, QSize requested, bool crop) {
    QImageReader reader(path);
    reader.setAutoTransform(true);
    QSize size = reader.size();
    if (reader.transformation() & QImageIOHandler::TransformationRotate90)
        size.transpose();
    if (size.isValid() && (requested.width() > 0 || requested.height() > 0)) {
        // As Qt's own Image: never larger than the file, aspect kept.
        QSize box = requested;
        if (box.width() <= 0)
            box.setWidth(size.width() * box.height() / std::max(1, size.height()));
        if (box.height() <= 0)
            box.setHeight(size.height() * box.width() / std::max(1, size.width()));
        QSize scaled = size.scaled(box, crop ? Qt::KeepAspectRatioByExpanding : Qt::KeepAspectRatio);
        if (scaled.width() < size.width() && scaled.height() < size.height()) {
            if (reader.transformation() & QImageIOHandler::TransformationRotate90)
                scaled.transpose();
            reader.setScaledSize(scaled);
        }
    }
    QImage image = reader.read();
    if (image.isNull())
        return image;
    // The scene graph's formats, so the upload is a copy, not a conversion.
    if (image.hasAlphaChannel())
        image.convertTo(QImage::Format_ARGB32_Premultiplied);
    else
        image.convertTo(QImage::Format_RGB32);
    return image;
}

StillTexture::StillTexture(QImage image, QString path, QSize requested, bool crop)
    : m_image(std::move(image)), m_path(std::move(path)), m_requested(requested), m_crop(crop), m_size(m_image.size()) {}

QSGTexture *StillTexture::createTexture(QQuickWindow *window) const {
    QImage image = m_image.isNull() && !m_path.isEmpty() ? StillProvider::load(m_path, m_requested, m_crop) : m_image;
    if (image.isNull()) {
        // A picture from memory, asked for again: it's gone; clear.
        image = QImage(1, 1, QImage::Format_ARGB32_Premultiplied);
        image.fill(Qt::transparent);
    }
    QSGTexture *texture = window->createTextureFromImage(image);
    // On the GPU now: the picture itself isn't needed any more.
    m_image = QImage();
    return texture;
}

QImage StillTexture::image() const {
    return m_image.isNull() && !m_path.isEmpty() ? StillProvider::load(m_path, m_requested, m_crop) : m_image;
}
