#include "annotationcanvas.h"

#include <QCursor>
#include <QDir>
#include <QFileInfo>
#include <QFontMetricsF>
#include <QKeyEvent>
#include <QLineF>
#include <QMouseEvent>
#include <QPainter>
#include <QPainterPath>
#include <QPolygonF>
#include <QUrl>

#include <algorithm>
#include <array>
#include <cmath>
#include <numbers>

namespace {

using Tool = AnnotationCanvas::Tool;

constexpr int kHistoryLimit = 50;
constexpr qreal kHighlighterAlpha = 0.45;
constexpr qreal kFillAlpha = 0.3;
// Display px: how near the pointer must be to pick an annotation up, and how
// far it moves before a freehand stroke takes another point.
constexpr qreal kHitTolerance = 8;
constexpr qreal kFreehandStep = 2.5;

constexpr std::array<std::pair<Tool, const char*>, 12> kToolNames = {{
    {Tool::Move, "move"},
    {Tool::Brush, "brush"},
    {Tool::Highlighter, "highlighter"},
    {Tool::Line, "line"},
    {Tool::Arrow, "arrow"},
    {Tool::Rectangle, "rectangle"},
    {Tool::Circle, "circle"},
    {Tool::Text, "text"},
    {Tool::Numbering, "numbering"},
    {Tool::Blur, "blur"},
    {Tool::Eraser, "eraser"},
    {Tool::Crop, "crop"},
}};

// Two-point drags: {start, end}.
bool isShape(Tool tool) {
    return tool == Tool::Line || tool == Tool::Arrow || tool == Tool::Rectangle || tool == Tool::Circle || tool == Tool::Blur;
}

qreal distanceToSegment(QPointF p, QPointF a, QPointF b) {
    const QPointF d = b - a;
    const qreal lengthSquared = QPointF::dotProduct(d, d);
    if (lengthSquared < 1e-6)
        return QLineF(p, a).length();
    const qreal t = std::clamp(QPointF::dotProduct(p - a, d) / lengthSquared, 0.0, 1.0);
    return QLineF(p, a + t * d).length();
}

qreal segmentDistance(QPointF a0, QPointF a1, QPointF b0, QPointF b1) {
    QPointF crossing;
    if (QLineF(a0, a1).intersects(QLineF(b0, b1), &crossing) == QLineF::BoundedIntersection)
        return 0;
    return std::min({distanceToSegment(a0, b0, b1), distanceToSegment(a1, b0, b1), distanceToSegment(b0, a0, a1),
                     distanceToSegment(b1, a0, a1)});
}

bool segmentHitsRect(QPointF a, QPointF b, const QRectF& rect) {
    if (rect.contains(a) || rect.contains(b))
        return true;
    const std::array<QLineF, 4> edges = {QLineF(rect.topLeft(), rect.topRight()), QLineF(rect.topRight(), rect.bottomRight()),
                                         QLineF(rect.bottomRight(), rect.bottomLeft()), QLineF(rect.bottomLeft(), rect.topLeft())};
    QPointF crossing;
    return std::ranges::any_of(edges, [&](const QLineF& edge) {
        return QLineF(a, b).intersects(edge, &crossing) == QLineF::BoundedIntersection;
    });
}

QPointF snap45(QPointF start, QPointF end) {
    const QPointF d = end - start;
    const qreal length = std::hypot(d.x(), d.y());
    if (length < 1e-4)
        return end;
    constexpr qreal step = std::numbers::pi / 4;
    const qreal angle = std::round(std::atan2(d.y(), d.x()) / step) * step;
    return start + QPointF(std::cos(angle), std::sin(angle)) * length;
}

QPointF snapSquare(QPointF start, QPointF end) {
    const QPointF d = end - start;
    const qreal side = std::max(std::abs(d.x()), std::abs(d.y()));
    return start + QPointF(d.x() < 0 ? -side : side, d.y() < 0 ? -side : side);
}

// A separable box blur over premultiplied pixels, in place.
void boxBlur(QImage& image, int radius) {
    const int w = image.width();
    const int h = image.height();
    if (w < 2 || h < 2 || radius < 1)
        return;
    QImage scratch(image.size(), image.format());
    const int span = radius * 2 + 1;
    const auto pass = [&](const QImage& from, QImage& to, bool horizontal) {
        const int lines = horizontal ? h : w;
        const int length = horizontal ? w : h;
        for (int line = 0; line < lines; ++line) {
            const auto at = [&](const QImage& img, int i) -> QRgb {
                const int c = std::clamp(i, 0, length - 1);
                return horizontal ? reinterpret_cast<const QRgb*>(img.constScanLine(line))[c]
                                  : reinterpret_cast<const QRgb*>(img.constScanLine(c))[line];
            };
            int r = 0, g = 0, b = 0, a = 0;
            for (int i = -radius; i <= radius; ++i) {
                const QRgb px = at(from, i);
                r += qRed(px), g += qGreen(px), b += qBlue(px), a += qAlpha(px);
            }
            for (int i = 0; i < length; ++i) {
                const QRgb out = qRgba(r / span, g / span, b / span, a / span);
                if (horizontal)
                    reinterpret_cast<QRgb*>(to.scanLine(line))[i] = out;
                else
                    reinterpret_cast<QRgb*>(to.scanLine(i))[line] = out;
                const QRgb gone = at(from, i - radius);
                const QRgb next = at(from, i + radius + 1);
                r += qRed(next) - qRed(gone), g += qGreen(next) - qGreen(gone);
                b += qBlue(next) - qBlue(gone), a += qAlpha(next) - qAlpha(gone);
            }
        }
    };
    for (int i = 0; i < 2; ++i) {
        pass(image, scratch, true);
        pass(scratch, image, false);
    }
}

QString localPath(const QString& source) {
    return source.startsWith(QStringLiteral("file:")) ? QUrl(source).toLocalFile() : source;
}

} // namespace

AnnotationCanvas::AnnotationCanvas(QQuickItem* parent) : QQuickPaintedItem(parent) {
    setAcceptedMouseButtons(Qt::LeftButton);
    setAcceptHoverEvents(true);
    setAntialiasing(true);
    setFlag(ItemAcceptsInputMethod, false);
    updateCursor();
}

// ── Properties ──────────────────────────────────────────────────────────

void AnnotationCanvas::setSource(const QString& source) {
    if (source == m_source)
        return;
    m_source = source;
    m_image = source.isEmpty() ? QImage() : QImage(localPath(source)).convertToFormat(QImage::Format_ARGB32_Premultiplied);
    m_items.clear();
    m_undo.clear();
    m_redo.clear();
    m_crop = {};
    m_live = false;
    setEditingText(false);
    setGesture(Gesture::None);
    emit sourceChanged();
    emit historyChanged();
    emit cropChanged();
    invalidate();
}

QString AnnotationCanvas::tool() const {
    for (const auto& [tool, name] : kToolNames)
        if (tool == m_tool)
            return QString::fromLatin1(name);
    return QStringLiteral("brush");
}

void AnnotationCanvas::setTool(const QString& name) {
    for (const auto& [tool, toolName] : kToolNames) {
        if (name == QLatin1StringView(toolName) && tool != m_tool) {
            commitText();
            if (busy())
                return;
            m_tool = tool;
            updateCursor();
            emit toolChanged();
            update();
            return;
        }
    }
}

void AnnotationCanvas::setColor(const QColor& color) {
    if (color == m_color)
        return;
    m_color = color;
    // Restyling while typing acts on the text being typed.
    if (m_textEditing && !m_items.isEmpty()) {
        m_items.last().stroke = color;
        update();
    }
    emit colorChanged();
}

void AnnotationCanvas::setStrokeWidth(qreal width) {
    if (qFuzzyCompare(width, m_strokeWidth))
        return;
    m_strokeWidth = width;
    if (m_textEditing && !m_items.isEmpty()) {
        m_items.last().width = toImageWidth(width);
        update();
    }
    emit strokeWidthChanged();
}

void AnnotationCanvas::setFill(bool fill) {
    if (fill == m_fill)
        return;
    m_fill = fill;
    emit fillChanged();
}

void AnnotationCanvas::setFontFamily(const QString& family) {
    if (family == m_fontFamily)
        return;
    m_fontFamily = family;
    emit fontFamilyChanged();
    invalidate();
}

void AnnotationCanvas::setAccent(const QColor& accent) {
    if (accent == m_accent)
        return;
    m_accent = accent;
    emit accentChanged();
    update();
}

// ── Geometry ────────────────────────────────────────────────────────────

// Image px -> canvas px. The item is expected at the image's aspect ratio.
qreal AnnotationCanvas::scale() const {
    if (m_image.isNull())
        return 1;
    return std::min(width() / m_image.width(), height() / m_image.height());
}

QPointF AnnotationCanvas::toImage(QPointF itemPoint) const {
    return itemPoint / std::max(scale(), 1e-4);
}

qreal AnnotationCanvas::toImageWidth(qreal displayWidth) const {
    return displayWidth / std::max(scale(), 1e-4);
}

void AnnotationCanvas::geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry) {
    QQuickPaintedItem::geometryChange(newGeometry, oldGeometry);
    update();
}

// ── History ─────────────────────────────────────────────────────────────

void AnnotationCanvas::beginStep() {
    m_undo.append(m_items);
    while (m_undo.size() > kHistoryLimit)
        m_undo.removeFirst();
    m_redo.clear();
}

void AnnotationCanvas::dropStep() {
    if (m_undo.isEmpty())
        return;
    m_items = m_undo.takeLast();
    renumber();
}

void AnnotationCanvas::undo() {
    commitText();
    if (busy() || m_undo.isEmpty())
        return;
    m_redo.append(m_items);
    m_items = m_undo.takeLast();
    renumber();
    emit historyChanged();
    invalidate();
}

void AnnotationCanvas::redo() {
    commitText();
    if (busy() || m_redo.isEmpty())
        return;
    m_undo.append(m_items);
    m_items = m_redo.takeLast();
    renumber();
    emit historyChanged();
    invalidate();
}

void AnnotationCanvas::renumber() {
    int n = 0;
    for (auto& item : m_items)
        if (item.tool == Tool::Numbering)
            item.text = QString::number(++n);
}

void AnnotationCanvas::clearCrop() {
    if (!m_crop.isValid())
        return;
    m_crop = {};
    emit cropChanged();
    update();
}

bool AnnotationCanvas::cancelGesture() {
    switch (m_gesture) {
    case Gesture::None:
        return false;
    case Gesture::Crop:
        m_crop = {};
        emit cropChanged();
        break;
    case Gesture::Draw:
    case Gesture::Move:
    case Gesture::Erase:
        dropStep();
        m_live = false;
        emit historyChanged();
        break;
    }
    setGesture(Gesture::None);
    invalidate();
    return true;
}

void AnnotationCanvas::setGesture(Gesture gesture) {
    if (gesture == m_gesture)
        return;
    const bool was = busy();
    m_gesture = gesture;
    if (busy() != was)
        emit busyChanged();
}

void AnnotationCanvas::setEditingText(bool editing) {
    if (editing == m_textEditing)
        return;
    m_textEditing = editing;
    emit editingTextChanged();
}

void AnnotationCanvas::commitText() {
    if (!m_textEditing)
        return;
    m_live = false;
    setEditingText(false);
    if (m_items.isEmpty() || m_items.last().text.isEmpty())
        dropStep();
    emit historyChanged();
    invalidate();
}

void AnnotationCanvas::cancelText() {
    if (!m_textEditing)
        return;
    m_live = false;
    setEditingText(false);
    dropStep();
    emit historyChanged();
    invalidate();
}

// ── Hit testing ─────────────────────────────────────────────────────────

QRectF AnnotationCanvas::textBox(const Annotation& a) const {
    QFont font(m_fontFamily);
    font.setBold(true);
    font.setPixelSize(std::max(1, int(std::round(a.width))));
    const QFontMetricsF metrics(font);
    const qreal w = metrics.horizontalAdvance(a.text.isEmpty() ? QStringLiteral(" ") : a.text);
    // The point is the left end of the text's middle line.
    return {a.points.first().x(), a.points.first().y() - metrics.height() / 2, w, metrics.height()};
}

bool AnnotationCanvas::touches(const Annotation& a, QPointF from, QPointF to, qreal radius) const {
    if (a.points.isEmpty())
        return false;
    const qreal reach = radius + a.width / 2;
    const QPointF start = a.points.first();
    const QPointF end = a.points.last();
    const QRectF box = QRectF(start, end).normalized();

    switch (a.tool) {
    case Tool::Text:
        return segmentHitsRect(from, to, textBox(a).adjusted(-radius, -radius, radius, radius));
    case Tool::Numbering:
        return distanceToSegment(start, from, to) <= reach;
    case Tool::Blur:
        return segmentHitsRect(from, to, box.adjusted(-radius, -radius, radius, radius));
    case Tool::Line:
    case Tool::Arrow:
        return segmentDistance(from, to, start, end) <= reach;
    case Tool::Rectangle: {
        if (a.fill.alpha() > 0 && segmentHitsRect(from, to, box))
            return true;
        const std::array<QLineF, 4> edges = {QLineF(box.topLeft(), box.topRight()), QLineF(box.topRight(), box.bottomRight()),
                                             QLineF(box.bottomRight(), box.bottomLeft()), QLineF(box.bottomLeft(), box.topLeft())};
        return std::ranges::any_of(edges, [&](const QLineF& e) { return segmentDistance(from, to, e.p1(), e.p2()) <= reach; });
    }
    case Tool::Circle: {
        const QPointF c = box.center();
        const qreal rx = std::max(box.width() / 2, 1e-4);
        const qreal ry = std::max(box.height() / 2, 1e-4);
        for (const QPointF probe : {from, to}) {
            const qreal n = std::hypot((probe.x() - c.x()) / rx, (probe.y() - c.y()) / ry);
            if ((a.fill.alpha() > 0 && n <= 1) || std::abs(n - 1) * std::min(rx, ry) <= reach)
                return true;
        }
        return false;
    }
    default:
        break;
    }

    if (a.points.size() == 1)
        return distanceToSegment(start, from, to) <= reach;
    for (qsizetype i = 1; i < a.points.size(); ++i)
        if (segmentDistance(from, to, a.points[i - 1], a.points[i]) <= reach)
            return true;
    return false;
}

int AnnotationCanvas::hitTest(QPointF point, qreal tolerance) const {
    for (qsizetype i = m_items.size(); i > 0; --i)
        if (touches(m_items[i - 1], point, point, tolerance))
            return int(i - 1);
    return -1;
}

// ── Pointer ─────────────────────────────────────────────────────────────

void AnnotationCanvas::mousePressEvent(QMouseEvent* event) {
    if (m_image.isNull() || event->button() != Qt::LeftButton) {
        event->ignore();
        return;
    }
    forceActiveFocus(Qt::MouseFocusReason);
    // A press elsewhere ends the text being typed.
    commitText();

    const QPointF point = toImage(event->position());
    const qreal width = toImageWidth(m_strokeWidth);
    m_last = point;
    // Off the image (the item may be larger than it): nothing to draw on.
    if (!QRectF(QPointF(0, 0), m_image.size()).contains(point))
        return;

    switch (m_tool) {
    case Tool::Move: {
        m_moveIndex = hitTest(point, toImageWidth(kHitTolerance));
        if (m_moveIndex < 0)
            return;
        beginStep();
        m_moved = false;
        setGesture(Gesture::Move);
        break;
    }
    case Tool::Eraser:
        beginStep();
        m_erased = false;
        setGesture(Gesture::Erase);
        mouseMoveEvent(event);
        break;
    case Tool::Crop:
        m_cropFrom = point;
        m_crop = {};
        emit cropChanged();
        setGesture(Gesture::Crop);
        break;
    case Tool::Text:
        beginStep();
        m_items.append({.tool = Tool::Text, .width = width, .stroke = m_color, .points = {point}});
        m_live = true;
        setEditingText(true);
        invalidate();
        break;
    case Tool::Numbering:
        beginStep();
        m_items.append({.tool = Tool::Numbering, .width = width, .stroke = m_color, .points = {point}});
        renumber();
        emit historyChanged();
        invalidate();
        break;
    default: {
        beginStep();
        Annotation a{.tool = m_tool, .width = width, .stroke = m_color, .points = {point}};
        if (m_fill && (m_tool == Tool::Rectangle || m_tool == Tool::Circle)) {
            a.fill = m_color;
            a.fill.setAlphaF(kFillAlpha);
        }
        if (isShape(m_tool))
            a.points.append(point);
        m_items.append(a);
        m_live = true;
        setGesture(Gesture::Draw);
        invalidate();
        break;
    }
    }
    update();
}

void AnnotationCanvas::mouseMoveEvent(QMouseEvent* event) {
    const QPointF point = toImage(event->position());
    m_hover = event->position();

    switch (m_gesture) {
    case Gesture::None:
        return;
    case Gesture::Move:
        if (m_moveIndex >= 0 && m_moveIndex < m_items.size()) {
            for (auto& p : m_items[m_moveIndex].points)
                p += point - m_last;
            m_moved = true;
            invalidate();
        }
        break;
    case Gesture::Erase: {
        const qreal radius = toImageWidth(m_strokeWidth) / 2;
        bool any = false;
        for (qsizetype i = m_items.size(); i > 0; --i) {
            if (touches(m_items[i - 1], m_last, point, radius)) {
                m_items.removeAt(i - 1);
                any = true;
            }
        }
        if (any) {
            m_erased = true;
            renumber();
            invalidate();
        }
        break;
    }
    case Gesture::Crop:
        m_crop = QRectF(m_cropFrom, point).normalized() & QRectF(QPointF(0, 0), m_image.size());
        emit cropChanged();
        break;
    case Gesture::Draw: {
        if (m_items.isEmpty())
            return;
        Annotation& a = m_items.last();
        if (isShape(a.tool)) {
            QPointF end = point;
            if (event->modifiers() & Qt::ShiftModifier)
                end = (a.tool == Tool::Line || a.tool == Tool::Arrow) ? snap45(a.points.first(), point)
                                                                     : snapSquare(a.points.first(), point);
            a.points.last() = end;
        } else {
            if (QLineF(a.points.last(), point).length() < toImageWidth(kFreehandStep))
                return;
            a.points.append(point);
        }
        break;
    }
    }
    m_last = point;
    update();
}

void AnnotationCanvas::mouseReleaseEvent(QMouseEvent* event) {
    Q_UNUSED(event)
    switch (m_gesture) {
    case Gesture::None:
        return;
    case Gesture::Move:
        if (!m_moved)
            dropStep();
        break;
    case Gesture::Erase:
        if (!m_erased)
            dropStep();
        break;
    case Gesture::Crop:
        if (m_crop.width() < 2 || m_crop.height() < 2) {
            m_crop = {};
            emit cropChanged();
        }
        break;
    case Gesture::Draw: {
        m_live = false;
        // A click with a shape tool draws nothing.
        const Annotation& a = m_items.last();
        if (isShape(a.tool) && QLineF(a.points.first(), a.points.last()).length() < toImageWidth(2))
            dropStep();
        break;
    }
    }
    m_moveIndex = -1;
    setGesture(Gesture::None);
    emit historyChanged();
    invalidate();
}

void AnnotationCanvas::hoverMoveEvent(QHoverEvent* event) {
    m_hover = event->position();
    if (m_tool == Tool::Eraser)
        update();
}

void AnnotationCanvas::updateCursor() {
    switch (m_tool) {
    case Tool::Move:
        setCursor(Qt::SizeAllCursor);
        break;
    case Tool::Text:
        setCursor(Qt::IBeamCursor);
        break;
    case Tool::Eraser:
        setCursor(Qt::BlankCursor);
        break;
    default:
        setCursor(Qt::CrossCursor);
        break;
    }
}

// ── Keys (only while typing) ────────────────────────────────────────────

void AnnotationCanvas::keyPressEvent(QKeyEvent* event) {
    if (!m_textEditing || m_items.isEmpty()) {
        event->ignore();
        return;
    }
    Annotation& a = m_items.last();
    switch (event->key()) {
    case Qt::Key_Return:
    case Qt::Key_Enter:
        commitText();
        break;
    case Qt::Key_Escape:
        cancelText();
        break;
    case Qt::Key_Backspace:
        if (!a.text.isEmpty()) {
            a.text.chop(a.text.size() > 1 && a.text.back().isLowSurrogate() ? 2 : 1);
            update();
        }
        break;
    default: {
        const QString text = event->text();
        if (!text.isEmpty() && text.front().isPrint()) {
            a.text += text;
            update();
        }
        // Every other key is swallowed so shortcuts can't fire mid-word.
        break;
    }
    }
    event->accept();
}

// ── Drawing ─────────────────────────────────────────────────────────────

QImage AnnotationCanvas::blurred(const QImage& background, const QRect& area, qreal strength) const {
    const QRect rect = area & background.rect();
    if (rect.isEmpty())
        return {};
    // Average down, blur the small copy, scale it back: the cost stays off the
    // region's area, and the detail lost is what the blur would remove.
    const int step = std::clamp(int(strength / 4), 2, 24);
    QImage small = background.copy(rect).scaled(std::max(1, rect.width() / step), std::max(1, rect.height() / step),
                                                Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
    small = small.convertToFormat(QImage::Format_ARGB32_Premultiplied);
    boxBlur(small, std::max(1, int(strength / step / 2)));
    return small.scaled(rect.size(), Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
}

void AnnotationCanvas::render(QPainter* p, const Annotation& a, const QImage& background) const {
    if (a.points.isEmpty())
        return;
    p->save();
    QPen pen(a.stroke, a.width, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin);
    p->setPen(pen);
    p->setBrush(Qt::NoBrush);
    const QPointF start = a.points.first();
    const QPointF end = a.points.last();

    switch (a.tool) {
    case Tool::Move:
    case Tool::Eraser:
    case Tool::Crop:
        break;

    case Tool::Brush:
        if (a.points.size() == 1) {
            p->setPen(Qt::NoPen);
            p->setBrush(a.stroke);
            p->drawEllipse(start, a.width / 2, a.width / 2);
        } else {
            // Through the midpoints, each point a control: a smooth stroke.
            QPainterPath path(start);
            for (qsizetype i = 1; i + 1 < a.points.size(); ++i)
                path.quadTo(a.points[i], (a.points[i] + a.points[i + 1]) / 2);
            path.lineTo(end);
            p->drawPath(path);
        }
        break;

    case Tool::Highlighter: {
        QColor c = a.stroke;
        c.setAlphaF(kHighlighterAlpha);
        if (a.points.size() == 1) {
            p->fillRect(QRectF(start.x() - a.width / 4, start.y() - a.width / 2, a.width / 2, a.width), c);
            break;
        }
        // One path, so overlaps don't darken.
        pen.setColor(c);
        pen.setCapStyle(Qt::SquareCap);
        p->setPen(pen);
        p->drawPolyline(QPolygonF(a.points));
        break;
    }

    case Tool::Line:
        p->drawLine(start, end);
        break;

    case Tool::Arrow: {
        const qreal head = std::max(12.0, a.width * 3);
        const qreal angle = std::atan2(end.y() - start.y(), end.x() - start.x());
        constexpr qreal spread = std::numbers::pi / 7;
        const QPointF left = end - head * QPointF(std::cos(angle - spread), std::sin(angle - spread));
        const QPointF right = end - head * QPointF(std::cos(angle + spread), std::sin(angle + spread));
        // The shaft stops inside the head so its round cap doesn't show past
        // the tip.
        const qreal length = QLineF(start, end).length();
        const QPointF shaftEnd = length > head * 0.6 ? end - head * 0.6 * QPointF(std::cos(angle), std::sin(angle)) : start;
        p->drawLine(start, shaftEnd);
        p->setPen(QPen(a.stroke, std::max(1.0, a.width / 3), Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin));
        p->setBrush(a.stroke);
        p->drawPolygon(QPolygonF({end, left, right}));
        break;
    }

    case Tool::Rectangle:
    case Tool::Circle: {
        const QRectF box = QRectF(start, end).normalized();
        if (a.fill.alpha() > 0)
            p->setBrush(a.fill);
        if (a.tool == Tool::Rectangle)
            p->drawRect(box);
        else
            p->drawEllipse(box);
        break;
    }

    case Tool::Text: {
        if (a.text.isEmpty())
            break;
        QFont font(m_fontFamily);
        font.setBold(true);
        font.setPixelSize(std::max(1, int(std::round(a.width))));
        p->setFont(font);
        const QRectF box = textBox(a);
        p->drawText(QPointF(box.left(), box.top() + QFontMetricsF(font).ascent()), a.text);
        break;
    }

    case Tool::Numbering: {
        p->setPen(Qt::NoPen);
        p->setBrush(a.stroke);
        p->drawEllipse(start, a.width / 2, a.width / 2);
        QFont font(m_fontFamily);
        font.setBold(true);
        font.setPixelSize(std::max(1, int(std::round(a.width * 0.6))));
        p->setFont(font);
        // The label reads against the disc's own colour.
        p->setPen(a.stroke.lightnessF() > 0.6 ? Qt::black : Qt::white);
        p->drawText(QRectF(start.x() - a.width / 2, start.y() - a.width / 2, a.width, a.width), Qt::AlignCenter,
                    a.text.isEmpty() ? QStringLiteral("?") : a.text);
        break;
    }

    case Tool::Blur: {
        const QRect area = QRectF(start, end).normalized().toAlignedRect();
        const QImage image = blurred(background, area, a.width);
        if (!image.isNull())
            p->drawImage((area & background.rect()).topLeft(), image);
        break;
    }
    }
    p->restore();
}

void AnnotationCanvas::invalidate() {
    m_cacheDirty = true;
    update();
}

void AnnotationCanvas::paint(QPainter* painter) {
    if (m_image.isNull())
        return;
    painter->setRenderHints(QPainter::Antialiasing | QPainter::SmoothPixmapTransform | QPainter::TextAntialiasing);

    const qsizetype committed = m_live ? m_items.size() - 1 : m_items.size();
    if (m_cacheDirty) {
        m_cache = m_image.copy();
        QPainter p(&m_cache);
        p.setRenderHints(QPainter::Antialiasing | QPainter::SmoothPixmapTransform | QPainter::TextAntialiasing);
        for (qsizetype i = 0; i < committed; ++i)
            render(&p, m_items[i], m_image);
        m_cacheDirty = false;
    }

    const qreal s = scale();
    const QRectF view(0, 0, m_image.width() * s, m_image.height() * s);
    painter->drawImage(view, m_cache);

    painter->save();
    painter->setClipRect(view);
    painter->scale(s, s);
    if (m_live && !m_items.isEmpty()) {
        const Annotation& a = m_items.last();
        render(painter, a, m_image);
        // The caret, after the text being typed.
        if (m_textEditing) {
            const QRectF box = textBox(a);
            const qreal x = a.text.isEmpty() ? box.left() : box.right() + a.width * 0.06;
            painter->setPen(QPen(m_accent, std::max(1.5, a.width / 12) , Qt::SolidLine, Qt::FlatCap));
            painter->drawLine(QPointF(x, box.top() + box.height() * 0.12), QPointF(x, box.bottom() - box.height() * 0.12));
        }
    }
    painter->restore();

    // The crop: everything outside it dimmed, a frame round it.
    if (m_crop.isValid()) {
        const QRectF crop(m_crop.topLeft() * s, m_crop.size() * s);
        QPainterPath outside;
        outside.addRect(view);
        outside.addRect(crop);
        painter->fillPath(outside, QColor(0, 0, 0, 150));
        painter->setPen(QPen(m_accent, 2));
        painter->setBrush(Qt::NoBrush);
        painter->drawRect(crop.adjusted(-1, -1, 1, 1));
    }

    // The eraser's reach, in place of the cursor.
    if (m_tool == Tool::Eraser && view.contains(m_hover)) {
        painter->setPen(QPen(m_accent, 1.5));
        painter->setBrush(Qt::NoBrush);
        painter->drawEllipse(m_hover, m_strokeWidth / 2, m_strokeWidth / 2);
    }
}

bool AnnotationCanvas::save(const QString& path) {
    commitText();
    if (m_image.isNull())
        return false;
    QImage out = m_image.copy();
    {
        QPainter p(&out);
        p.setRenderHints(QPainter::Antialiasing | QPainter::SmoothPixmapTransform | QPainter::TextAntialiasing);
        for (const auto& item : std::as_const(m_items))
            render(&p, item, m_image);
    }
    if (m_crop.isValid())
        out = out.copy(m_crop.toAlignedRect() & out.rect());
    const QString file = localPath(path);
    QDir().mkpath(QFileInfo(file).absolutePath());
    return out.save(file, "PNG");
}
