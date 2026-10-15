#include "surfacefx.h"

#include <QQmlEngine>
#include <QQmlParserStatus>
#include <QTimer>
#include <private/qquickhoverhandler_p.h>
#include <private/qquickitem_p.h>
#include <private/qquickrectangle_p.h>
#include <private/qquicktaphandler_p.h>

#include <cmath>

SurfaceFxTicker::SurfaceFxTicker(SurfaceFx *fx) : m_fx(fx) {}

void SurfaceFxTicker::updateCurrentTime(int time) {
    m_fx->tick(time);
}

SurfaceFx::SurfaceFx(QQuickItem *parent) : QQuickItem(parent) {}

SurfaceFx::~SurfaceFx() {
    if (m_ticker) {
        m_ticker->stop();
        delete m_ticker;
    }
}

bool SurfaceFx::hovered() const {
    return m_hover && m_hover->isHovered();
}

bool SurfaceFx::pressed() const {
    return m_tap && m_tap->isPressed();
}

QPointF SurfaceFx::hoverAt() const {
    return m_hover && m_hover->isHovered() ? m_hover->point().position() : QPointF(-1, -1);
}

QPointF SurfaceFx::hoverScene() const {
    return m_hover && m_hover->isHovered() ? m_hover->point().scenePosition() : QPointF(-1, -1);
}

void SurfaceFx::componentComplete() {
    QQuickItem::componentComplete();
    attach();
}

void SurfaceFx::itemChange(ItemChange change, const ItemChangeData &data) {
    QQuickItem::itemChange(change, data);
    if (change == ItemParentHasChanged && isComponentComplete())
        attach();
}

void SurfaceFx::attach() {
    if (m_surface)
        disconnect(m_surface, nullptr, this, nullptr);
    if (m_live)
        goStill();
    m_surface = qobject_cast<QQuickRectangle *>(parentItem());
    if (!m_surface)
        return;
    connect(m_surface, &QQuickItem::widthChanged, this, &SurfaceFx::fitParent);
    connect(m_surface, &QQuickItem::heightChanged, this, &SurfaceFx::fitParent);
    connectInput("interactive", "syncInteractive()");
    connectInput("holdToConfirm", "syncHoldMode()");
    fitParent();
    syncInteractive();
}

bool SurfaceFx::connectInput(const char *name, const char *slot) {
    const QMetaObject *mo = m_surface->metaObject();
    const int pi = mo->indexOfProperty(name);
    if (pi < 0)
        return false;
    const QMetaProperty p = mo->property(pi);
    const int si = staticMetaObject.indexOfSlot(slot);
    if (!p.hasNotifySignal() || si < 0)
        return false;
    return connect(m_surface, p.notifySignal(), this, staticMetaObject.method(si), Qt::UniqueConnection);
}

QVariant SurfaceFx::read(const char *name) const {
    return m_surface ? m_surface->property(name) : QVariant();
}

QObject *SurfaceFx::tokens() const {
    static QPointer<QObject> cached;
    if (!cached) {
        if (QQmlEngine *e = qmlEngine(this))
            cached = e->singletonInstance<QObject *>("qs.config", "Tokens");
    }
    return cached;
}

int SurfaceFx::dur(const char *name) const {
    if (QObject *t = tokens())
        if (auto *anim = t->property("anim").value<QObject *>())
            return anim->property(name).toInt();
    return 200;
}

QEasingCurve SurfaceFx::curve(const char *name) const {
    QEasingCurve c(QEasingCurve::BezierSpline);
    QList<qreal> pts;
    if (QObject *t = tokens())
        if (auto *anim = t->property("anim").value<QObject *>())
            pts = anim->property(name).value<QList<qreal>>();
    if (pts.size() < 6 || pts.size() % 6)
        return QEasingCurve(QEasingCurve::OutCubic);
    for (int i = 0; i + 5 < pts.size(); i += 6)
        c.addCubicBezierSegment(QPointF(pts[i], pts[i + 1]), QPointF(pts[i + 2], pts[i + 3]), QPointF(pts[i + 4], pts[i + 5]));
    return c;
}

void SurfaceFx::fitParent() {
    if (!m_surface)
        return;
    setSize(m_surface->size());
    if (m_layerRect)
        m_layerRect->setSize(size());
    placeRipple();
    placeHold();
}

void SurfaceFx::syncInteractive() {
    const bool on = read("interactive").toBool();
    if (on && !m_live)
        goLive();
    else if (!on && m_live)
        goStill();
}

void SurfaceFx::goLive() {
    m_live = true;
    QQuickRectangle *s = m_surface;
    m_inkProp = QQmlProperty(s, QStringLiteral("ink"));
    m_subInkProp = QQmlProperty(s, QStringLiteral("subInk"));
    m_holdProp = QQmlProperty(s, QStringLiteral("hold"));

    // As the QML Bindings did (RestoreBindingOrValue): the surface's own
    // bindings put aside while it's interactive.
    for (const char *name : {"color", "ink", "subInk", "radius", "scale"}) {
        QQmlProperty prop(s, QString::fromLatin1(name));
        if (!prop.isValid())
            continue;
        Taken t;
        t.prop = prop;
        t.value = prop.read();
        t.binding = QQmlAnyBinding::takeFrom(prop);
        m_taken.append(std::move(t));
    }
    for (auto &tw : m_tw)
        tw.on = false;
    m_bounce = Spring();
    m_fill = read("fill").value<QColor>();
    m_ink = read("baseInk").value<QColor>();
    m_subInk = read("baseSubInk").value<QColor>();
    m_radius = read("shapeRadius").toReal();
    applyColor(Fill, m_fill);
    applyColor(Ink, m_ink);
    applyColor(SubInk, m_subInk);
    applyReal(Radius, m_radius);
    applyBounce(1);

    m_hover = new QQuickHoverHandler(this);
    m_hover->setCursorShape(Qt::PointingHandCursor);
    m_tap = new QQuickTapHandler(this);
    m_tap->setAcceptedButtons(Qt::LeftButton | Qt::RightButton | Qt::MiddleButton);
    for (QQuickPointerHandler *h : {static_cast<QQuickPointerHandler *>(m_hover), static_cast<QQuickPointerHandler *>(m_tap)}) {
        static_cast<QQmlParserStatus *>(h)->classBegin();
        QQuickItemPrivate::get(this)->addPointerHandler(h);
        static_cast<QQmlParserStatus *>(h)->componentComplete();
    }
    connect(m_hover, &QQuickHoverHandler::hoveredChanged, this, [this] {
        emit hoveredChanged();
        emit hoverMoved();
        syncLayer();
    });
    connect(m_hover, &QQuickSinglePointHandler::pointChanged, this, [this] {
        if (m_hover->isHovered())
            emit hoverMoved();
    });
    connect(m_tap, &QQuickTapHandler::pressedChanged, this, &SurfaceFx::onPressed);
    connect(m_tap, &QQuickTapHandler::tapped, this, &SurfaceFx::onTapped);

    connectInput("fill", "syncFill()");
    connectInput("baseInk", "syncInk()");
    connectInput("baseSubInk", "syncSubInk()");
    connectInput("shapeRadius", "syncShape()");
    connectInput("hoverLayer", "syncLayer()");
    connectInput("keyFocused", "syncLayer()");
    connect(s, &QQuickRectangle::radiusChanged, this, &SurfaceFx::syncCorners, Qt::UniqueConnection);
    connect(s, &QQuickRectangle::topLeftRadiusChanged, this, &SurfaceFx::syncCorners, Qt::UniqueConnection);
    connect(s, &QQuickRectangle::topRightRadiusChanged, this, &SurfaceFx::syncCorners, Qt::UniqueConnection);
    connect(s, &QQuickRectangle::bottomLeftRadiusChanged, this, &SurfaceFx::syncCorners, Qt::UniqueConnection);
    connect(s, &QQuickRectangle::bottomRightRadiusChanged, this, &SurfaceFx::syncCorners, Qt::UniqueConnection);
    syncHoldMode();
    syncLayer();
    emit hoveredChanged();
    emit pressedChanged();
    emit hoverMoved();
}

void SurfaceFx::goStill() {
    m_live = false;
    const bool wasHovered = hovered(), wasPressed = pressed();
    delete m_hover;
    delete m_tap;
    m_hover = nullptr;
    m_tap = nullptr;
    if (m_ticker)
        m_ticker->stop();
    for (auto &tw : m_tw)
        tw.on = false;
    m_bounce.on = false;
    if (m_surface) {
        disconnect(m_surface, nullptr, this, nullptr);
        connect(m_surface, &QQuickItem::widthChanged, this, &SurfaceFx::fitParent);
        connect(m_surface, &QQuickItem::heightChanged, this, &SurfaceFx::fitParent);
        connectInput("interactive", "syncInteractive()");
        connectInput("holdToConfirm", "syncHoldMode()");
    }
    for (auto &t : m_taken) {
        if (t.binding)
            t.binding.installOn(t.prop);
        else
            t.prop.write(t.value);
    }
    m_taken.clear();
    delete m_holdRect;
    delete m_rippleRect;
    delete m_layerRect;
    m_holdRect = m_rippleRect = m_layerRect = nullptr;
    m_layer = m_rippleP = m_rippleO = 0;
    if (m_hold != 0) {
        m_hold = 0;
        m_holdProp.write(0.0);
    }
    if (wasHovered)
        emit hoveredChanged(), emit hoverMoved();
    if (wasPressed)
        emit pressedChanged();
}

void SurfaceFx::syncHoldMode() {
    const bool on = m_live && read("holdToConfirm").toBool();
    if (on == m_holdMode)
        return;
    m_holdMode = on;
    if (on)
        connect(m_surface, SIGNAL(clicked()), this, SLOT(onSurfaceClicked()), Qt::UniqueConnection);
    else if (m_surface)
        disconnect(m_surface, SIGNAL(clicked()), this, SLOT(onSurfaceClicked()));
}

// ---- inputs -----------------------------------------------------------------

void SurfaceFx::syncFill() {
    startColor(Fill, read("fill").value<QColor>());
}

void SurfaceFx::syncInk() {
    startColor(Ink, read("baseInk").value<QColor>());
}

void SurfaceFx::syncSubInk() {
    startColor(SubInk, read("baseSubInk").value<QColor>());
}

void SurfaceFx::syncShape() {
    const qreal to = read("shapeRadius").toReal();
    startReal(Radius, m_radius, to, dur("fast"), curve("expressiveFastSpatial"));
}

void SurfaceFx::syncLayer() {
    if (!m_live)
        return;
    const bool on = (hovered() && read("hoverLayer").toBool()) || read("keyFocused").toBool();
    startReal(Layer, m_layer, on ? 0.08 : 0, dur("hover"), curve("standard"));
}

void SurfaceFx::syncCorners() {
    if (!m_surface)
        return;
    if (m_layerRect) {
        m_layerRect->setRadius(m_surface->radius());
        m_layerRect->setTopLeftRadius(m_surface->topLeftRadius());
        m_layerRect->setTopRightRadius(m_surface->topRightRadius());
        m_layerRect->setBottomLeftRadius(m_surface->bottomLeftRadius());
        m_layerRect->setBottomRightRadius(m_surface->bottomRightRadius());
    }
    placeRipple();
    placeHold();
}

void SurfaceFx::onPressed() {
    const bool p = m_tap->isPressed();
    if (p)
        m_surface->setProperty("pressPoint", m_tap->point().position());
    emit pressedChanged();

    // The press: ink spreading from where it landed, fading on release.
    if (p) {
        m_tw[RippleO].on = false;
        applyReal(RippleO, 0.14);
        startReal(RippleP, 0, 1, dur("normal"), curve("emphasizedDecel"));
    } else {
        startReal(RippleO, m_rippleO, 0, dur("normal"), QEasingCurve(QEasingCurve::OutQuad));
    }

    // Press physics: a squash that springs back past rest.
    startBounce(p ? read("pressDepth").toReal() : 1);

    // Hold to confirm: ink fills over holdMs; let go early and it drains.
    if (m_holdMode) {
        if (p)
            startReal(Hold, m_hold, 1, int(read("holdMs").toInt() * (1 - m_hold)), QEasingCurve(QEasingCurve::Linear));
        else if (m_hold < 1)
            startReal(Hold, m_hold, 0, dur("normal"), QEasingCurve(QEasingCurve::OutCubic));
    }
}

void SurfaceFx::onTapped(QEventPoint, Qt::MouseButton button) {
    if (!m_surface)
        return;
    if (button == Qt::RightButton)
        QMetaObject::invokeMethod(m_surface, "rightClicked");
    else if (button == Qt::MiddleButton)
        QMetaObject::invokeMethod(m_surface, "middleClicked");
    else
        QMetaObject::invokeMethod(m_surface, "clicked");
}

void SurfaceFx::onSurfaceClicked() {
    // A click alone on a hold-to-confirm: say "Hold to confirm" a moment.
    m_surface->setProperty("hinting", true);
    if (!m_hint) {
        m_hint = new QTimer(this);
        m_hint->setSingleShot(true);
        m_hint->setInterval(1600);
        connect(m_hint, &QTimer::timeout, this, [this] {
            if (m_surface)
                m_surface->setProperty("hinting", false);
        });
    }
    m_hint->start();
}

// ---- animation ----------------------------------------------------------------

void SurfaceFx::ensureTicker() {
    if (!m_ticker)
        m_ticker = new SurfaceFxTicker(this);
    if (m_ticker->state() != QAbstractAnimationJob::Running) {
        // start() ticks at 0 at once, before the caller has set up what's
        // to move: that tick mustn't see nothing moving and stop it.
        m_starting = true;
        m_ticker->start();
        m_starting = false;
    }
}

// Behavior semantics: from where it is now to the new value, the whole
// duration again.
void SurfaceFx::startColor(Channel ch, QColor to) {
    const QColor now = ch == Fill ? m_fill : ch == Ink ? m_ink : m_subInk;
    Tween &tw = m_tw[ch];
    if (!tw.on && now == to)
        return;
    const int d = dur("normal");
    if (d <= 0) {
        tw.on = false;
        applyColor(ch, to);
        return;
    }
    ensureTicker();
    tw.on = true;
    tw.start = m_ticker->currentTime();
    tw.duration = d;
    tw.ease = curve("standard");
    tw.cFrom = now;
    tw.cTo = to;
}

void SurfaceFx::startReal(Channel ch, qreal from, qreal to, int duration, const QEasingCurve &ease) {
    Tween &tw = m_tw[ch];
    if (duration <= 0) {
        tw.on = false;
        applyReal(ch, to);
        if (ch == Hold && to >= 1) {
            applyReal(Hold, 0);
            QMetaObject::invokeMethod(m_surface, "confirmed");
        }
        return;
    }
    if (!tw.on && from == to && ch != RippleP)
        return;
    ensureTicker();
    tw.on = true;
    tw.start = m_ticker->currentTime();
    tw.duration = duration;
    tw.ease = ease;
    tw.from = from;
    tw.to = to;
    if (ch == RippleP)
        applyReal(RippleP, from);
}

void SurfaceFx::startBounce(qreal to) {
    if (m_bounce.to == to && !m_bounce.on && m_bounce.value == to)
        return;
    ensureTicker();
    if (!m_bounce.on)
        m_bounce.last = m_ticker->currentTime();
    m_bounce.on = true;
    m_bounce.to = to;
}

void SurfaceFx::tick(int time) {
    bool any = false;
    for (int i = 0; i < Count; i++) {
        Tween &tw = m_tw[i];
        if (!tw.on)
            continue;
        const qreal t = std::clamp(qreal(time - tw.start) / tw.duration, 0.0, 1.0);
        const qreal e = t >= 1 ? 1 : tw.ease.valueForProgress(t);
        const auto ch = Channel(i);
        if (ch == Fill || ch == Ink || ch == SubInk) {
            // ColorAnimation: each channel in RGB, linearly by the eased progress.
            const QColor &a = tw.cFrom, &b = tw.cTo;
            QColor c = t >= 1 ? b : QColor::fromRgbF(float(a.redF() + (b.redF() - a.redF()) * e), float(a.greenF() + (b.greenF() - a.greenF()) * e), float(a.blueF() + (b.blueF() - a.blueF()) * e), float(a.alphaF() + (b.alphaF() - a.alphaF()) * e));
            applyColor(ch, c);
        } else {
            applyReal(ch, t >= 1 ? tw.to : tw.from + (tw.to - tw.from) * e);
        }
        if (t >= 1) {
            tw.on = false;
            if (ch == Hold && tw.to >= 1) {
                applyReal(Hold, 0);
                QMetaObject::invokeMethod(m_surface, "confirmed");
            }
        } else {
            any = true;
        }
    }

    // Qt's SpringAnimation, as it integrates: steps of 16 ms.
    if (m_bounce.on) {
        const int elapsed = time - m_bounce.last;
        if (elapsed >= 16) {
            const int count = elapsed / 16;
            m_bounce.last = time - (elapsed - count * 16);
            qreal spring = 4.5, damping = 0.22;
            if (QObject *t = tokens())
                if (auto *sp = t->property("spring").value<QObject *>())
                    if (auto *b = sp->property("bouncy").value<QObject *>()) {
                        spring = b->property("spring").toReal();
                        damping = b->property("damping").toReal();
                    }
            for (int i = 0; i < count; ++i) {
                const qreal diff = m_bounce.to - m_bounce.value;
                m_bounce.velocity = m_bounce.velocity + spring * diff - damping * m_bounce.velocity;
                m_bounce.value += m_bounce.velocity * 16.0 / 1000.0;
            }
            constexpr qreal epsilon = 0.002;
            if (std::abs(m_bounce.velocity) < epsilon && std::abs(m_bounce.to - m_bounce.value) < epsilon) {
                m_bounce.velocity = 0;
                m_bounce.value = m_bounce.to;
                m_bounce.on = false;
            }
            applyBounce(m_bounce.value);
        }
        if (m_bounce.on)
            any = true;
    }

    if (!any && m_ticker && !m_starting)
        m_ticker->stop();
}

QQuickRectangle *SurfaceFx::rect(QQuickRectangle *&r, qreal z) {
    if (!r) {
        r = new QQuickRectangle(this);
        r->setZ(z);
        r->setVisible(false);
    }
    return r;
}

void SurfaceFx::applyColor(Channel ch, QColor c) {
    if (!m_surface)
        return;
    switch (ch) {
    case Fill:
        m_fill = c;
        m_surface->setColor(c);
        break;
    case Ink:
        m_ink = c;
        m_inkProp.write(c);
        if (m_rippleRect)
            m_rippleRect->setColor(c);
        if (m_layerRect)
            m_layerRect->setColor(c);
        break;
    case SubInk:
        m_subInk = c;
        m_subInkProp.write(c);
        break;
    default:
        break;
    }
}

void SurfaceFx::applyReal(Channel ch, qreal v) {
    if (!m_surface)
        return;
    switch (ch) {
    case Radius:
        m_radius = v;
        m_surface->setRadius(v);
        break;
    case Layer: {
        m_layer = v;
        if (v > 0 || m_layerRect) {
            QQuickRectangle *r = rect(m_layerRect, 2);
            if (!r->isVisible() && v > 0) {
                r->setSize(size());
                r->setColor(m_ink);
                syncCorners();
            }
            r->setOpacity(v);
            r->setVisible(v > 0);
        }
        break;
    }
    case RippleP:
        m_rippleP = v;
        placeRipple();
        break;
    case RippleO:
        m_rippleO = v;
        placeRipple();
        break;
    case Hold:
        m_hold = v;
        m_holdProp.write(v);
        placeHold();
        break;
    default:
        break;
    }
}

void SurfaceFx::applyBounce(qreal v) {
    if (m_surface)
        m_surface->setScale(v);
}

// InkSpread (components/InkSpread.qml): a drop at `origin` growing into the
// surface's rounded rectangle as p goes 0 -> 1.
static void spread(QQuickRectangle *r, QSizeF box, QPointF origin, qreal p, qreal r1) {
    const qreal drop = 8;
    const qreal w0 = std::min(drop * 2, box.width()), h0 = std::min(drop * 2, box.height());
    const qreal x0 = std::max(0.0, std::min(box.width() - w0, origin.x() - w0 / 2));
    const qreal y0 = std::max(0.0, std::min(box.height() - h0, origin.y() - h0 / 2));
    const qreal w = w0 + (box.width() - w0) * p, h = h0 + (box.height() - h0) * p;
    const qreal m = std::min(w, h) / 2;
    r->setX(x0 * (1 - p));
    r->setY(y0 * (1 - p));
    r->setSize(QSizeF(w, h));
    r->setRadius(m + (std::min(r1, m) - m) * p);
}

void SurfaceFx::placeRipple() {
    if (!m_surface || (!m_rippleRect && (m_rippleP <= 0.001 || m_rippleO <= 0)))
        return;
    QQuickRectangle *r = rect(m_rippleRect, 1);
    const bool show = m_rippleP > 0.001 && m_rippleO > 0;
    if (show) {
        r->setColor(m_ink);
        r->setOpacity(m_rippleO);
        spread(r, size(), m_surface->property("pressPoint").toPointF(), m_rippleP, m_surface->radius());
    }
    r->setVisible(show);
}

void SurfaceFx::placeHold() {
    if (!m_surface || (!m_holdRect && m_hold <= 0.001))
        return;
    QQuickRectangle *r = rect(m_holdRect, 0);
    const bool show = m_holdMode && m_hold > 0.001;
    if (show) {
        if (!r->isVisible()) {
            // The theme's colour (Colours.roleFill("primary", "strong", 0)).
            QColor c;
            if (QQmlEngine *e = qmlEngine(this))
                if (QObject *colours = e->singletonInstance<QObject *>("qs.services", "Colours"))
                    QMetaObject::invokeMethod(colours, "roleFill", Q_RETURN_ARG(QColor, c), Q_ARG(QString, QStringLiteral("primary")), Q_ARG(QString, QStringLiteral("strong")), Q_ARG(int, 0));
            r->setColor(c);
        }
        spread(r, size(), QPointF(width() / 2, height() / 2), m_hold, m_surface->radius());
    }
    r->setVisible(show);
}
