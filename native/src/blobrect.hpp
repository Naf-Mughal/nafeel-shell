// Adapted from Ryoku (ryoku/shell/plugin/blobrect.hpp, GPL-3.0, github.com/ryoku-dev/ryoku),
// whose blob rendering is itself adapted from Caelestia (GPL-3.0). Changes for
// nafeel/shell are marked "nafeel:".
#pragma once

#include "blobshape.hpp"

#include <algorithm>

#include <qelapsedtimer.h>
#include <qpointer.h>
#include <qqmlengine.h>
#include <qqmllist.h>

class BlobRect : public BlobShape {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(qreal stiffness READ stiffness WRITE setStiffness NOTIFY stiffnessChanged)
    Q_PROPERTY(qreal damping READ damping WRITE setDamping NOTIFY dampingChanged)
    Q_PROPERTY(qreal deformScale READ deformScale WRITE setDeformScale NOTIFY deformScaleChanged)
    // nafeel: each axis stretches with its own speed, nothing shears (a corner
    // growing diagonally bounces outward instead of tilting); and the cap.
    Q_PROPERTY(bool axisAligned MEMBER m_axisAligned NOTIFY deformScaleChanged)
    Q_PROPERTY(qreal maxStretch MEMBER m_maxStretch NOTIFY deformScaleChanged)
    // nafeel: how wet the ink is (0..1) from outside (a drawer opening or
    // closing); the shape adds its own speed to it.
    Q_PROPERTY(qreal wet READ wet WRITE setWet NOTIFY wetChanged)
    // nafeel: the point the squash and stretch is pinned to, from the centre
    // in half-sizes (-1 left/top .. 1 right/bottom): a drawer pinned to the
    // bar it grows out of wobbles only at its free edge, so it stays part of
    // the bar. (0, 0) = about the centre, as Ryoku does.
    Q_PROPERTY(QPointF anchor MEMBER m_anchor NOTIFY deformScaleChanged)
    Q_PROPERTY(QQmlListProperty<BlobRect> exclude READ exclude NOTIFY excludeChanged)
    Q_PROPERTY(qreal topLeftRadius READ topLeftRadius WRITE setTopLeftRadius NOTIFY topLeftRadiusChanged)
    Q_PROPERTY(qreal topRightRadius READ topRightRadius WRITE setTopRightRadius NOTIFY topRightRadiusChanged)
    Q_PROPERTY(qreal bottomLeftRadius READ bottomLeftRadius WRITE setBottomLeftRadius NOTIFY bottomLeftRadiusChanged)
    Q_PROPERTY(
        qreal bottomRightRadius READ bottomRightRadius WRITE setBottomRightRadius NOTIFY bottomRightRadiusChanged)

public:
    explicit BlobRect(QQuickItem* parent = nullptr);
    ~BlobRect() override;

    qreal stiffness() const { return m_stiffness; }

    void setStiffness(qreal s) {
        if (!qFuzzyCompare(m_stiffness, s)) {
            m_stiffness = s;
            emit stiffnessChanged();
        }
    }

    qreal damping() const { return m_damping; }

    void setDamping(qreal d) {
        if (!qFuzzyCompare(m_damping, d)) {
            m_damping = d;
            emit dampingChanged();
        }
    }

    qreal deformScale() const { return m_deformScale; }

    void setDeformScale(qreal s) {
        if (!qFuzzyCompare(m_deformScale, s)) {
            m_deformScale = s;
            emit deformScaleChanged();
        }
    }

    QQmlListProperty<BlobRect> exclude();

    bool isExcluded(const BlobShape* other) const override;
    float wetness() const override { return std::max(static_cast<float>(m_wet), m_speedWet); }
    qreal wet() const { return m_wet; }
    void setWet(qreal w);
    void cornerRadii(float out[4]) const override;

    qreal topLeftRadius() const { return m_topLeftRadius; }

    void setTopLeftRadius(qreal r);

    qreal topRightRadius() const { return m_topRightRadius; }

    void setTopRightRadius(qreal r);

    qreal bottomLeftRadius() const { return m_bottomLeftRadius; }

    void setBottomLeftRadius(qreal r);

    qreal bottomRightRadius() const { return m_bottomRightRadius; }

    void setBottomRightRadius(qreal r);

signals:
    void stiffnessChanged();
    void dampingChanged();
    void deformScaleChanged();
    void excludeChanged();
    void wetChanged();
    void topLeftRadiusChanged();
    void topRightRadiusChanged();
    void bottomLeftRadiusChanged();
    void bottomRightRadiusChanged();

protected:
    void updatePolish() override;
    void updatePhysics() override;

private:
    void checkAtRest(float speed);

    // physics state
    QPointF m_prevScenePos;
    QElapsedTimer m_elapsed;
    bool m_physicsActive = false;
    bool m_hasPrevPos = false;

    // symmetric 2x2 deformation matrix, 3 independent components (m00, m01,
    // m11). rest = identity: m00=1, m01=0, m11=1.
    float m_dm00 = 1.0f;
    float m_dm01 = 0.0f;
    float m_dm11 = 1.0f;

    // spring velocity per component
    float m_dmVel00 = 0.0f;
    float m_dmVel01 = 0.0f;
    float m_dmVel11 = 0.0f;

    qreal m_stiffness = 200.0;
    qreal m_damping = 16.0;
    qreal m_deformScale = 0.0005;
    bool m_axisAligned = false;
    QPointF m_anchor{ 0, 0 };
    qreal m_wet = 0;
    float m_speedWet = 0.0f;
    qreal m_maxStretch = 0.35;

    qreal m_topLeftRadius = -1;
    qreal m_topRightRadius = -1;
    qreal m_bottomLeftRadius = -1;
    qreal m_bottomRightRadius = -1;

    QList<QPointer<BlobRect>> m_exclude;

    static void excludeAppend(QQmlListProperty<BlobRect>* prop, BlobRect* rect);
    static qsizetype excludeCount(QQmlListProperty<BlobRect>* prop);
    static BlobRect* excludeAt(QQmlListProperty<BlobRect>* prop, qsizetype index);
    static void excludeClear(QQmlListProperty<BlobRect>* prop);
    static void excludeReplace(QQmlListProperty<BlobRect>* prop, qsizetype index, BlobRect* rect);
    static void excludeRemoveLast(QQmlListProperty<BlobRect>* prop);
};
