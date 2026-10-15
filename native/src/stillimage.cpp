#include "stillimage.h"

#include <QImageReader>
#include <QQuickWindow>
#include <QRunnable>
#include <QUrl>

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

QQuickImageResponse *StillProvider::requestImageResponse(const QString &id, const QSize &requestedSize) {
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
    QImage image = m_image.isNull() ? StillProvider::load(m_path, m_requested, m_crop) : m_image;
    QSGTexture *texture = window->createTextureFromImage(image);
    // On the GPU now: the picture itself isn't needed any more.
    m_image = QImage();
    return texture;
}

QImage StillTexture::image() const {
    return m_image.isNull() ? StillProvider::load(m_path, m_requested, m_crop) : m_image;
}
