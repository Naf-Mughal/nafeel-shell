#pragma once

#include <private/qabstractanimationjob_p.h>
#include <QColor>
#include <QEasingCurve>
#include <QPointer>
#include <QQmlProperty>
#include <QQuickItem>
#include <QtQml/qqmlregistration.h>
#include <private/qqmlanybinding_p.h>

class QQuickRectangle;
class QQuickHoverHandler;
class QQuickTapHandler;
class QTimer;
class SurfaceFx;

// Its clock: a QML animation job (QQmlAnimationTimer, as Behaviors run on),
// so it steps exactly as the shell's other animations do.
class SurfaceFxTicker : public QAbstractAnimationJob {
public:
    explicit SurfaceFxTicker(SurfaceFx *fx);
    // Long enough for anything; it stops itself when everything settles.
    int duration() const override { return 1 << 30; }

protected:
    void updateCurrentTime(int time) override;

private:
    SurfaceFx *m_fx;
};

// A Surface's interaction, in one native item (components/Surface.qml).
//
// What an interactive Surface does: the state layer's hover tint, the press
// ripple, the press bounce (a spring past rest), the Expressive shape morph,
// fills and inks fading between states, hold to confirm. In QML that was ~25
// objects a surface (Behaviors, Bindings, animations, two handlers, three
// rectangles, a Connections) for ~900 interactive surfaces, warm in every
// panel: ~40 MB. Here it's this item, its two pointer handlers, and the
// rectangles made the first time they show. The motion is the same: the
// same durations and curves (read from Tokens when a change starts), Qt's
// own spring integration for the bounce, advanced on the shell's animation
// driver (the vblank pacer).
//
// It reads its parent Surface's properties (fill, baseInk, baseSubInk,
// shapeRadius, pressDepth, hoverLayer, keyFocused, holdToConfirm, holdMs)
// and, while the surface is interactive, owns its color, ink, subInk,
// radius and scale as the QML Bindings did (the surface's own bindings are
// put back when it stops being interactive).
class SurfaceFx : public QQuickItem {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool hovered READ hovered NOTIFY hoveredChanged FINAL)
    Q_PROPERTY(bool pressed READ pressed NOTIFY pressedChanged FINAL)
    Q_PROPERTY(QPointF hoverAt READ hoverAt NOTIFY hoverMoved FINAL)
    Q_PROPERTY(QPointF hoverScene READ hoverScene NOTIFY hoverMoved FINAL)

public:
    explicit SurfaceFx(QQuickItem *parent = nullptr);
    ~SurfaceFx() override;

    bool hovered() const;
    bool pressed() const;
    QPointF hoverAt() const;
    QPointF hoverScene() const;

    void tick(int time);

signals:
    void hoveredChanged();
    void pressedChanged();
    void hoverMoved();

protected:
    void componentComplete() override;
    void itemChange(ItemChange change, const ItemChangeData &data) override;

private slots:
    void syncInteractive();
    void syncFill();
    void syncInk();
    void syncSubInk();
    void syncShape();
    void syncLayer();
    void syncCorners();
    void syncHoldMode();
    void onPressed();
    void onTapped(QEventPoint point, Qt::MouseButton button);
    void onSurfaceClicked();
    void fitParent();

private:
    enum Channel { Fill, Ink, SubInk, Radius, Layer, RippleP, RippleO, Hold, Count };
    struct Tween {
        bool on = false;
        int start = 0;
        int duration = 0;
        QEasingCurve ease;
        QColor cFrom, cTo;
        qreal from = 0, to = 0;
    };
    struct Spring {
        bool on = false;
        qreal value = 1, to = 1, velocity = 0;
        int last = 0;
    };

    void attach();
    void goLive();
    void goStill();
    bool connectInput(const char *name, const char *slot);
    QVariant read(const char *name) const;
    QObject *tokens() const;
    int dur(const char *name) const;
    QEasingCurve curve(const char *name) const;

    void startColor(Channel ch, QColor to);
    void startReal(Channel ch, qreal from, qreal to, int duration, const QEasingCurve &ease);
    void startBounce(qreal to);
    void ensureTicker();
    void applyColor(Channel ch, QColor c);
    void applyReal(Channel ch, qreal v);
    void applyBounce(qreal v);
    void placeRipple();
    void placeHold();
    QQuickRectangle *rect(QQuickRectangle *&r, qreal z);

    QPointer<QQuickRectangle> m_surface;
    bool m_live = false;
    QQuickHoverHandler *m_hover = nullptr;
    QQuickTapHandler *m_tap = nullptr;
    SurfaceFxTicker *m_ticker = nullptr;
    QTimer *m_hint = nullptr;

    // Bindings and values the surface had before going live (put back).
    struct Taken {
        QQmlProperty prop;
        QQmlAnyBinding binding;
        QVariant value;
    };
    QList<Taken> m_taken;
    QQmlProperty m_inkProp, m_subInkProp, m_holdProp;

    Tween m_tw[Count];
    Spring m_bounce;
    QColor m_fill, m_ink, m_subInk;
    qreal m_radius = 0, m_layer = 0, m_rippleP = 0, m_rippleO = 0, m_hold = 0;
    bool m_holdMode = false;
    bool m_starting = false;

    QQuickRectangle *m_holdRect = nullptr;
    QQuickRectangle *m_rippleRect = nullptr;
    QQuickRectangle *m_layerRect = nullptr;
};
