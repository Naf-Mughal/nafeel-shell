#include "windowthumb.h"

#include "capture.h"

#include <QQuickWindow>
#include <QSGImageNode>
#include <QSGTexture>

#include <algorithm>
#include <cmath>

WindowThumb::WindowThumb(QQuickItem *parent) : QQuickItem(parent) {
    setFlag(ItemHasContents);
    m_pace.setSingleShot(true);
    m_pace.setTimerType(Qt::PreciseTimer);
    connect(&m_pace, &QTimer::timeout, this, [this] {
        if (m_session)
            m_session->request();
    });
    m_retry.setSingleShot(true);
    m_retry.setInterval(250);
    connect(&m_retry, &QTimer::timeout, this, &WindowThumb::requestNext);
    // A thumb whose window wasn't listed yet tries again as windows appear.
    connect(Capture::instance(), &Capture::windowsChanged, this, [this] {
        if (!m_session)
            sync();
    });
}

WindowThumb::~WindowThumb() { dropSession(); }

void WindowThumb::setWindowId(const QString &id) {
    if (id == m_windowId)
        return;
    m_windowId = id;
    dropSession();
    m_shown = false;
    const bool wasReady = ready();
    m_image = QImage();
    m_textureDirty = true;
    if (wasReady)
        emit readyChanged();
    update();
    emit windowIdChanged();
    sync();
}

void WindowThumb::setLive(bool live) {
    if (live == m_live)
        return;
    m_live = live;
    emit liveChanged();
    if (m_live)
        requestNext();
}

void WindowThumb::setFps(int fps) {
    fps = std::clamp(fps, 1, 240);
    if (fps == m_fps)
        return;
    m_fps = fps;
    emit fpsChanged();
}

void WindowThumb::setCrop(bool crop) {
    if (crop == m_crop)
        return;
    m_crop = crop;
    emit cropChanged();
    emit paintedRectChanged();
    update();
}

QRectF WindowThumb::paintedRect() const {
    if (m_sourceSize.isEmpty() || width() <= 0 || height() <= 0)
        return QRectF(0, 0, width(), height());
    const qreal sx = width() / m_sourceSize.width();
    const qreal sy = height() / m_sourceSize.height();
    const qreal scale = m_crop ? std::max(sx, sy) : std::min(sx, sy);
    const qreal w = m_sourceSize.width() * scale, h = m_sourceSize.height() * scale;
    return QRectF((width() - w) / 2, (height() - h) / 2, w, h);
}

bool WindowThumb::wanted() const {
    return !m_windowId.isEmpty() && isVisible() && window() && window()->isVisible() && width() > 0 && height() > 0;
}

void WindowThumb::sync() {
    if (!wanted()) {
        if (m_session)
            dropSession();
        m_shown = false;
        return;
    }
    if (m_session)
        return;
    m_session = Capture::instance()->session(m_windowId, this);
    if (!m_session)
        return;
    connect(m_session, &CaptureSession::frame, this, &WindowThumb::onFrame);
    connect(m_session, &CaptureSession::failed, &m_retry, qOverload<>(&QTimer::start));
    connect(m_session, &CaptureSession::stopped, this, [this] {
        // The window closed: keep its last frame, let the session go.
        if (m_session)
            m_session->deleteLater();
        m_session = nullptr;
    });
    requestNext();
}

void WindowThumb::dropSession() {
    m_pace.stop();
    m_retry.stop();
    delete m_session.data();
    m_session = nullptr;
}

void WindowThumb::requestNext() {
    if (!m_session || (!m_live && m_shown))
        return;
    // Hold the request until a frame interval has passed since the last one;
    // the compositor then holds the frame until the window changes.
    const qint64 interval = 1000 / m_fps;
    const qint64 elapsed = m_since.isValid() ? m_since.elapsed() : interval;
    if (elapsed >= interval) {
        m_session->request();
    } else {
        m_pace.start(int(interval - elapsed));
    }
}

// Scale the frame down to about the size it's drawn at (never below it):
// average four samples spread over each block, cheap enough per frame.
static QImage shrink(const uchar *pixels, QSize size, int stride, bool alpha, int target) {
    const QImage::Format format = alpha ? QImage::Format_ARGB32_Premultiplied : QImage::Format_RGB32;
    const int longest = std::max(size.width(), size.height());
    const int factor = std::max(1, longest / std::max(64, target));
    if (factor == 1)
        return QImage(pixels, size.width(), size.height(), stride, format).copy();

    const int ow = size.width() / factor, oh = size.height() / factor;
    QImage out(ow, oh, format);
    const int half = factor / 2;
    for (int oy = 0; oy < oh; oy++) {
        const auto *r0 = reinterpret_cast<const uint32_t *>(pixels + size_t(oy * factor) * stride);
        const auto *r1 = reinterpret_cast<const uint32_t *>(pixels + size_t(oy * factor + half) * stride);
        auto *dst = reinterpret_cast<uint32_t *>(out.scanLine(oy));
        for (int ox = 0; ox < ow; ox++) {
            const int x0 = ox * factor, x1 = x0 + half;
            const uint32_t a = r0[x0], b = r0[x1], c = r1[x0], d = r1[x1];
            // Per channel: (a + b + c + d) / 4, on even and odd bytes at once.
            const uint64_t lo = uint64_t(a & 0x00ff00ff) + (b & 0x00ff00ff) + (c & 0x00ff00ff) + (d & 0x00ff00ff);
            const uint64_t hi = uint64_t((a >> 8) & 0x00ff00ff) + ((b >> 8) & 0x00ff00ff) + ((c >> 8) & 0x00ff00ff) +
                                ((d >> 8) & 0x00ff00ff);
            dst[ox] = uint32_t(((lo >> 2) & 0x00ff00ff) | (((hi >> 2) & 0x00ff00ff) << 8));
        }
    }
    return out;
}

void WindowThumb::onFrame(const uchar *pixels, QSize size, int stride, bool alpha) {
    m_since.start();
    m_shown = true;

    const qreal dpr = window() ? window()->effectiveDevicePixelRatio() : 1.0;
    // Drawn size in device pixels along the picture's longer side.
    const QRectF painted = paintedRect();
    const int target = int(std::ceil(std::max(painted.width(), painted.height()) * dpr));
    const bool wasReady = ready();
    m_image = shrink(pixels, size, stride, alpha, target);
    m_textureDirty = true;
    update();

    if (size != m_sourceSize) {
        m_sourceSize = size;
        emit sourceSizeChanged();
        emit paintedRectChanged();
    }
    if (!wasReady)
        emit readyChanged();
    if (m_live)
        requestNext();
}

QSGNode *WindowThumb::updatePaintNode(QSGNode *old, UpdatePaintNodeData *) {
    auto *node = static_cast<QSGImageNode *>(old);
    if (m_image.isNull()) {
        delete node;
        return nullptr;
    }
    if (!node) {
        node = window()->createImageNode();
        node->setOwnsTexture(true);
        node->setFiltering(QSGTexture::Linear);
        m_textureDirty = true;
    }
    if (m_textureDirty) {
        node->setTexture(window()->createTextureFromImage(m_image, m_image.hasAlphaChannel()
                                                                       ? QQuickWindow::TextureHasAlphaChannel
                                                                       : QQuickWindow::CreateTextureOptions()));
        m_textureDirty = false;
    }

    const QSizeF tex = node->texture()->textureSize();
    QRectF target = paintedRect();
    QRectF source(0, 0, tex.width(), tex.height());
    if (m_crop) {
        // Show the middle of the picture that fits the item.
        const QRectF item(0, 0, width(), height());
        const qreal sx = tex.width() / target.width(), sy = tex.height() / target.height();
        source = QRectF((item.x() - target.x()) * sx, (item.y() - target.y()) * sy, item.width() * sx,
                        item.height() * sy);
        target = item;
    }
    node->setRect(target);
    node->setSourceRect(source);
    return node;
}

void WindowThumb::itemChange(ItemChange change, const ItemChangeData &data) {
    QQuickItem::itemChange(change, data);
    if (change == ItemSceneChange) {
        disconnect(m_windowVisible);
        if (data.window)
            m_windowVisible = connect(data.window, &QWindow::visibleChanged, this, &WindowThumb::sync);
        sync();
    } else if (change == ItemVisibleHasChanged) {
        sync();
    }
}

void WindowThumb::geometryChange(const QRectF &now, const QRectF &before) {
    QQuickItem::geometryChange(now, before);
    if (now.size() != before.size()) {
        emit paintedRectChanged();
        update();
        if (!m_session)
            sync();
    }
}
