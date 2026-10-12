#pragma once

#include <QColor>
#include <QImage>
#include <QList>
#include <QPointF>
#include <QQuickPaintedItem>
#include <QRectF>
#include <QString>
#include <QtQml/qqmlregistration.h>

// The annotator's canvas: an image with annotations drawn over it, edited
// with the pointer. Tools (behaviour after Noctalia's annotator): move, brush,
// highlighter, line, arrow, rectangle, circle, text, numbering, blur, eraser,
// crop. Shift snaps lines to 45° and shapes to squares. One undo step per
// gesture. Coordinates are the image's pixels; widths are given in the
// canvas's (display) pixels and kept in image pixels.
//
//   AnnotationCanvas { source: "/path/shot.png"; tool: "arrow"; color: "red"; strokeWidth: 6 }
//   canvas.save(path)   the image with its annotations (cropped), as PNG
//
// While a text annotation is being typed the canvas takes the keys (Enter
// keeps it, Esc drops it); otherwise keys pass on to QML.
class AnnotationCanvas : public QQuickPaintedItem {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(QSize imageSize READ imageSize NOTIFY sourceChanged)
    Q_PROPERTY(QString tool READ tool WRITE setTool NOTIFY toolChanged)
    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY colorChanged)
    Q_PROPERTY(qreal strokeWidth READ strokeWidth WRITE setStrokeWidth NOTIFY strokeWidthChanged)
    Q_PROPERTY(bool fill READ fill WRITE setFill NOTIFY fillChanged)
    Q_PROPERTY(QString fontFamily READ fontFamily WRITE setFontFamily NOTIFY fontFamilyChanged)
    Q_PROPERTY(QColor accent READ accent WRITE setAccent NOTIFY accentChanged)
    Q_PROPERTY(bool canUndo READ canUndo NOTIFY historyChanged)
    Q_PROPERTY(bool canRedo READ canRedo NOTIFY historyChanged)
    Q_PROPERTY(int count READ count NOTIFY historyChanged)
    Q_PROPERTY(bool editingText READ editingText NOTIFY editingTextChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(bool hasCrop READ hasCrop NOTIFY cropChanged)
    Q_PROPERTY(QRectF crop READ crop NOTIFY cropChanged)

public:
    enum class Tool { Move, Brush, Highlighter, Line, Arrow, Rectangle, Circle, Text, Numbering, Blur, Eraser, Crop };

    struct Annotation {
        Tool tool = Tool::Brush;
        qreal width = 6; // image px; Text: font px; Numbering: diameter
        QColor stroke;
        QColor fill = Qt::transparent;
        QList<QPointF> points;
        QString text;
    };

    explicit AnnotationCanvas(QQuickItem* parent = nullptr);

    void paint(QPainter* painter) override;

    QString source() const { return m_source; }
    void setSource(const QString& source);
    QSize imageSize() const { return m_image.size(); }
    QString tool() const;
    void setTool(const QString& tool);
    QColor color() const { return m_color; }
    void setColor(const QColor& color);
    qreal strokeWidth() const { return m_strokeWidth; }
    void setStrokeWidth(qreal width);
    bool fill() const { return m_fill; }
    void setFill(bool fill);
    QString fontFamily() const { return m_fontFamily; }
    void setFontFamily(const QString& family);
    QColor accent() const { return m_accent; }
    void setAccent(const QColor& accent);
    bool canUndo() const { return !m_undo.isEmpty(); }
    bool canRedo() const { return !m_redo.isEmpty(); }
    int count() const { return int(m_items.size()); }
    bool editingText() const { return m_textEditing; }
    bool busy() const { return m_gesture != Gesture::None; }
    bool hasCrop() const { return m_crop.isValid(); }
    QRectF crop() const { return m_crop; }

    Q_INVOKABLE void undo();
    Q_INVOKABLE void redo();
    Q_INVOKABLE void clearCrop();
    // Ends a drag (Esc): what it changed is dropped.
    Q_INVOKABLE bool cancelGesture();
    Q_INVOKABLE void commitText();
    Q_INVOKABLE void cancelText();
    // The image with its annotations, cropped, written as PNG at `path`.
    Q_INVOKABLE bool save(const QString& path);

signals:
    void sourceChanged();
    void toolChanged();
    void colorChanged();
    void strokeWidthChanged();
    void fillChanged();
    void fontFamilyChanged();
    void accentChanged();
    void historyChanged();
    void editingTextChanged();
    void busyChanged();
    void cropChanged();

protected:
    void mousePressEvent(QMouseEvent* event) override;
    void mouseMoveEvent(QMouseEvent* event) override;
    void mouseReleaseEvent(QMouseEvent* event) override;
    void hoverMoveEvent(QHoverEvent* event) override;
    void keyPressEvent(QKeyEvent* event) override;
    void geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry) override;

private:
    enum class Gesture { None, Draw, Move, Erase, Crop };

    qreal scale() const;
    QPointF toImage(QPointF itemPoint) const;
    qreal toImageWidth(qreal displayWidth) const;
    void beginStep();
    void dropStep();
    void setGesture(Gesture gesture);
    void setEditingText(bool editing);
    void renumber();
    void invalidate();
    void updateCursor();
    int hitTest(QPointF point, qreal tolerance) const;
    bool touches(const Annotation& a, QPointF from, QPointF to, qreal radius) const;
    QRectF textBox(const Annotation& a) const;
    void render(QPainter* p, const Annotation& a, const QImage& background) const;
    QImage blurred(const QImage& background, const QRect& area, qreal strength) const;

    QString m_source;
    QImage m_image;
    // The image with every annotation but the one being drawn, at image size.
    QImage m_cache;
    bool m_cacheDirty = true;

    Tool m_tool = Tool::Brush;
    QColor m_color = QColor(245, 51, 71);
    qreal m_strokeWidth = 6;
    bool m_fill = false;
    QString m_fontFamily = QStringLiteral("sans-serif");
    QColor m_accent = QColor(255, 255, 255);

    QList<Annotation> m_items;
    QList<QList<Annotation>> m_undo;
    QList<QList<Annotation>> m_redo;
    // The annotation being drawn or typed (the last one), not in the cache.
    bool m_live = false;
    bool m_textEditing = false;
    Gesture m_gesture = Gesture::None;
    QPointF m_last;
    QPointF m_cropFrom;
    int m_moveIndex = -1;
    bool m_moved = false;
    bool m_erased = false;
    QRectF m_crop;
    QPointF m_hover;
};
