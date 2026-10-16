#pragma once

#include <QObject>
#include <QStringList>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

// Fuzzy matching for the launcher (fzf's way of scoring, simplified): a
// query's characters in order, case-insensitively, scored for runs of
// consecutive characters, word starts (after a separator, a camelCase hump,
// a digit run) and the very start, less for gaps. A query of several words
// matches when every word does, in any order. Native: every keystroke scores
// every app, setting and window (and files later), and JS was the cost.
class Fuzzy : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    using QObject::QObject;

    struct Match {
        int score = 0;
        QList<int> positions;
    };

    // One string: its score (0 = no match).
    Q_INVOKABLE int score(const QString &text, const QString &query) const;

    // One string: { score, positions } (positions of the matched characters,
    // for highlighting), or null when it doesn't match.
    Q_INVOKABLE QVariant match(const QString &text, const QString &query) const;

    // Many strings at once: their scores, in order (0 = no match).
    Q_INVOKABLE QList<int> scores(const QStringList &texts, const QString &query) const;

    // `text` with the matched characters wrapped for a rich-text label
    // (`open`/`close`, e.g. a coloured <b>), the rest escaped.
    Q_INVOKABLE QString highlight(const QString &text, const QString &query, const QString &open, const QString &close) const;

    static Match matchAll(const QString &text, const QString &query);

private:
    static Match matchTerm(const QString &text, const QString &term);
};
