#pragma once

#include <QObject>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

#include <atomic>
#include <functional>
#include <future>
#include <memory>
#include <mutex>
#include <thread>
#include <vector>

// The clipboard and its history: Noctalia's ClipboardService (and its
// encrypted history, its secret-service key, its virtual-keyboard paste),
// ported 1:1 under src/noctalia (MIT, Copyright (c) 2026 noctalia-dev), run on
// a worker thread with Noctalia's own poll loop and its own Wayland
// connection. The history is the same files Noctalia keeps
// (~/.local/state/noctalia/clipboard), with the same key from the keyring, so
// it carries over as it is.
//
// QML sees `entries` (newest first, pinned at the top, as Noctalia orders
// them): { id, preview, mime, image, pinned, time (ms), bytes }.
class Clipboard : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QVariantList entries READ entries NOTIFY entriesChanged)
    // The encrypted history: "opening" | "ready" | "unavailable" | "cancelled"
    // | "locked" | "missing-key" | "recovery" | "error".
    Q_PROPERTY(QString state READ state NOTIFY stateChanged)
    Q_PROPERTY(bool available READ available NOTIFY stateChanged)

public:
    explicit Clipboard(QObject *parent = nullptr);
    ~Clipboard() override;

    QVariantList entries() const { return m_entries; }
    QString state() const { return m_state; }
    bool available() const { return m_available; }

    // Copy an entry (moving it to the top unless pinned) and, with `paste`,
    // type the paste shortcut into the focused window `pasteDelay` ms later
    // (time for the panel to let go of the keyboard).
    Q_INVOKABLE void activate(int index, bool paste, int pasteDelay = 220);
    Q_INVOKABLE void togglePin(int index);
    Q_INVOKABLE void remove(int index);
    Q_INVOKABLE void clearUnpinned();
    Q_INVOKABLE void clearAll();
    Q_INVOKABLE void copyText(const QString &text);
    // Copy a PNG file as an image (a screenshot, say).
    Q_INVOKABLE void copyImageFile(const QString &path);
    Q_INVOKABLE void retry();
    // The whole text of an entry (loads its payload), or "".
    Q_INVOKABLE QString text(int index);
    // An image entry as a data: URL for an Image, or "".
    Q_INVOKABLE QString imageUrl(int index);

signals:
    void entriesChanged();
    void stateChanged();

private:
    struct Worker;

    void post(std::function<void(Worker &)> fn);
    template <typename T> T call(std::function<T(Worker &)> fn, T fallback);
    void publish(QVariantList entries, QString state, bool available);

    std::unique_ptr<Worker> m_worker;
    std::thread m_thread;
    QVariantList m_entries;
    QString m_state = QStringLiteral("opening");
    bool m_available = false;
};
