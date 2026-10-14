#pragma once

#include <QFont>
#include <QGuiApplication>
#include <QObject>
#include <QtQml/qqmlregistration.h>

// Where text in the shell's fonts finds the glyphs those fonts lack. Qt's
// own fallback asks fontconfig, which picks the system's whole Noto CJK
// collections for a Chinese gloss (a font engine each, its tables copied:
// ~8 MB a family, mapped files on top). A substitute is tried first, so the
// shell's cut CJK font (bin/build-cjk-font) answers for every family it names.
class Fonts : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    using QObject::QObject;

    // `fallback` stands in for each of `families` (and the application's
    // default family, which unstyled text uses) where they have no glyph.
    Q_INVOKABLE void substitute(const QStringList &families, const QString &fallback) const {
        QStringList all = families;
        all.append(QGuiApplication::font().family());
        for (const QString &f : std::as_const(all)) {
            if (f.isEmpty() || f == fallback || QFont::substitutes(f).contains(fallback))
                continue;
            QFont::insertSubstitution(f, fallback);
        }
    }
};
