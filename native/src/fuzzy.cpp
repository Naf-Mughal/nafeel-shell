#include "fuzzy.h"

#include <algorithm>

namespace {

// Scores (after fzf's): every matched character earns `Char`; one right after
// the previous match earns `Run` more; one at a word start earns `Boundary`
// (`Start` at the very start); a gap costs `GapOpen` once and `GapExtend` per
// extra character.
constexpr int Char = 16;
constexpr int Run = 8;
constexpr int Boundary = 20;
constexpr int Start = 24;
constexpr int GapOpen = 3;
constexpr int GapExtend = 1;
// The whole term as one piece starting a word ("chr" in "Chrome"): a bonus
// on top. Mid-word ("ff" in "Waffle") earns nothing extra: word starts are
// what people type.
constexpr int Substring = 16;

bool separator(QChar c) {
    return c.isSpace() || c == '-' || c == '_' || c == '.' || c == '/' || c == '\\' || c == ':' || c == ',' || c == '(' || c == '[';
}

// Whether `i` starts a word in `text`.
bool wordStart(const QString &text, int i) {
    if (i == 0)
        return true;
    const QChar p = text[i - 1], c = text[i];
    if (separator(p))
        return true;
    if (p.isLower() && c.isUpper())
        return true;
    if (!p.isDigit() && c.isDigit())
        return true;
    return false;
}

} // namespace

Fuzzy::Match Fuzzy::matchTerm(const QString &text, const QString &term) {
    Match m;
    if (term.isEmpty())
        return m;
    const QString t = text.toCaseFolded(), q = term.toCaseFolded();
    const int n = t.size(), k = q.size();
    if (k > n)
        return m;

    // Forward: the earliest end of a match; then backward from there for the
    // tightest start (fzf v1). Tried from each place the first character
    // occurs, keeping the best: a later, tighter match at a word start beats
    // an early scattered one ("ws" in "Wallpaper Settings").
    int best = 0;
    QList<int> bestPos;
    for (int from = t.indexOf(q[0]); from >= 0 && from < n; from = t.indexOf(q[0], from + 1)) {
        int qi = 0, end = -1;
        for (int i = from; i < n; i++) {
            if (t[i] == q[qi] && ++qi == k) {
                end = i;
                break;
            }
        }
        if (end < 0)
            break; // no later start can match either
        QList<int> pos(k);
        qi = k - 1;
        for (int i = end; i >= from && qi >= 0; i--)
            if (t[i] == q[qi])
                pos[qi--] = i;
        int s = 0, prev = -2;
        for (int j = 0; j < k; j++) {
            const int i = pos[j];
            s += Char;
            if (i == prev + 1)
                s += Run;
            else if (prev >= 0)
                s -= GapOpen + GapExtend * (i - prev - 2);
            if (wordStart(text, i))
                s += i == 0 ? Start : Boundary;
            prev = i;
        }
        if (pos[k - 1] - pos[0] == k - 1 && wordStart(text, pos[0]))
            s += Substring;
        if (s > best) {
            best = s;
            bestPos = pos;
        }
    }
    // A short text that's nearly all match ranks above a long one.
    if (best > 0)
        best += std::clamp(16 - (n - k), 0, 8);
    m.score = std::max(best, best > 0 ? 1 : 0);
    m.positions = bestPos;
    return m;
}

Fuzzy::Match Fuzzy::matchAll(const QString &text, const QString &query) {
    Match all;
    const QStringList terms = query.split(QChar(' '), Qt::SkipEmptyParts);
    if (terms.isEmpty())
        return all;
    for (const QString &term : terms) {
        Match m = matchTerm(text, term);
        if (m.score <= 0)
            return Match{};
        all.score += m.score;
        all.positions += m.positions;
    }
    std::sort(all.positions.begin(), all.positions.end());
    all.positions.erase(std::unique(all.positions.begin(), all.positions.end()), all.positions.end());
    return all;
}

int Fuzzy::score(const QString &text, const QString &query) const {
    return matchAll(text, query).score;
}

QVariant Fuzzy::match(const QString &text, const QString &query) const {
    const Match m = matchAll(text, query);
    if (m.score <= 0)
        return {};
    QVariantList pos;
    for (int p : m.positions)
        pos.append(p);
    return QVariantMap{{"score", m.score}, {"positions", pos}};
}

QList<int> Fuzzy::scores(const QStringList &texts, const QString &query) const {
    QList<int> out;
    out.reserve(texts.size());
    for (const QString &t : texts)
        out.append(matchAll(t, query).score);
    return out;
}

QString Fuzzy::highlight(const QString &text, const QString &query, const QString &open, const QString &close) const {
    const Match m = matchAll(text, query);
    QString out;
    int pi = 0;
    bool in = false;
    for (int i = 0; i < text.size(); i++) {
        const bool hit = pi < m.positions.size() && m.positions[pi] == i;
        if (hit)
            pi++;
        if (hit && !in) {
            out += open;
            in = true;
        } else if (!hit && in) {
            out += close;
            in = false;
        }
        out += QString(text[i]).toHtmlEscaped();
    }
    if (in)
        out += close;
    return out;
}
