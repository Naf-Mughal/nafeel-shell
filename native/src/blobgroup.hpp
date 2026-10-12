// Adapted from Ryoku (ryoku/shell/plugin/blobgroup.hpp, GPL-3.0, github.com/ryoku-dev/ryoku),
// whose blob rendering is itself adapted from Caelestia (GPL-3.0). Changes for
// nafeel/shell are marked "nafeel:".
#pragma once

#include <qcolor.h>
#include <qlist.h>
#include <qobject.h>
#include <qqmlengine.h>

class BlobShape;
class BlobInvertedRect;

class BlobGroup : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(qreal smoothing READ smoothing WRITE setSmoothing NOTIFY smoothingChanged)
    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY colorChanged)
    Q_PROPERTY(qreal shadowStrength READ shadowStrength WRITE setShadowStrength NOTIFY shadowStrengthChanged)
    Q_PROPERTY(qreal shadowSize READ shadowSize WRITE setShadowSize NOTIFY shadowSizeChanged)
    Q_PROPERTY(QColor borderColor READ borderColor WRITE setBorderColor NOTIFY borderColorChanged)
    Q_PROPERTY(qreal borderWidth READ borderWidth WRITE setBorderWidth NOTIFY borderWidthChanged)
    // nafeel: the paper. Ink wash and grain strength, paper fibre strength,
    // and a gilded line just outside the shape in `accent`.
    Q_PROPERTY(qreal ink MEMBER m_ink WRITE setInk NOTIFY paperChanged)
    Q_PROPERTY(qreal fibre MEMBER m_fibre WRITE setFibre NOTIFY paperChanged)
    Q_PROPERTY(qreal gild MEMBER m_gild WRITE setGild NOTIFY paperChanged)
    Q_PROPERTY(QColor accent MEMBER m_accent WRITE setAccent NOTIFY paperChanged)

public:
    explicit BlobGroup(QObject* parent = nullptr);
    ~BlobGroup() override;

    qreal smoothing() const { return m_smoothing; }

    void setSmoothing(qreal s);

    QColor color() const { return m_color; }

    void setColor(const QColor& c);

    qreal shadowStrength() const { return m_shadowStrength; }
    void setShadowStrength(qreal v);

    qreal shadowSize() const { return m_shadowSize; }
    void setShadowSize(qreal v);

    QColor borderColor() const { return m_borderColor; }
    void setBorderColor(const QColor& c);

    qreal borderWidth() const { return m_borderWidth; }
    void setBorderWidth(qreal v);

    void setInk(qreal v) { m_ink = v; emit paperChanged(); markDirty(); }
    void setFibre(qreal v) { m_fibre = v; emit paperChanged(); markDirty(); }
    void setGild(qreal v) { m_gild = v; emit paperChanged(); markDirty(); }
    void setAccent(const QColor& c) { m_accent = c; emit paperChanged(); markDirty(); }
    qreal ink() const { return m_ink; }
    qreal fibre() const { return m_fibre; }
    qreal gild() const { return m_gild; }
    QColor accent() const { return m_accent; }

    void addShape(BlobShape* shape);
    void removeShape(BlobShape* shape);

    void setInvertedRect(BlobInvertedRect* rect);
    void clearInvertedRect(BlobInvertedRect* rect);

    const QList<BlobShape*>& shapes() const { return m_shapes; }

    BlobInvertedRect* invertedRect() const { return m_invertedRect; }

    void markDirty();
    void markShapeDirty(BlobShape* source);
    void ensurePhysicsUpdated();

signals:
    void smoothingChanged();
    void colorChanged();
    void shadowStrengthChanged();
    void shadowSizeChanged();
    void borderColorChanged();
    void borderWidthChanged();
    void paperChanged();

private:
    qreal m_smoothing = 32.0;
    QColor m_color{ 0x44, 0x88, 0xff };
    qreal m_shadowStrength = 0.0;
    qreal m_shadowSize = 0.0;
    QColor m_borderColor{ 0, 0, 0, 0 };
    qreal m_borderWidth = 0.0;
    qreal m_ink = 0.0;
    qreal m_fibre = 0.0;
    qreal m_gild = 0.0;
    QColor m_accent{ 0, 0, 0, 0 };
    QList<BlobShape*> m_shapes;
    BlobInvertedRect* m_invertedRect = nullptr;
    bool m_physicsUpdated = false;
};
