#include "clipboard.h"

#include "noctalia/security/secret_store.h"
#include "noctalia/security/secure_buffer.h"
#include "noctalia/security/storage_key_provider.h"
#include "noctalia/wayland/clipboard_poll_source.h"
#include "noctalia/wayland/clipboard_service.h"
#include "noctalia/wayland/virtual_keyboard_service.h"

#include <QDebug>
#include <QFile>
#include <QMetaObject>
#include <QPointer>
#include <QTimer>

#include <cerrno>
#include <chrono>
#include <cstring>
#include <deque>
#include <poll.h>
#include <sys/eventfd.h>
#include <unistd.h>

#include <wayland-client.h>

#include "virtual-keyboard-unstable-v1-client-protocol.h"

namespace {
QString stateName(ClipboardPersistenceState s) {
    switch (s) {
    case ClipboardPersistenceState::Opening:
        return QStringLiteral("opening");
    case ClipboardPersistenceState::Ready:
        return QStringLiteral("ready");
    case ClipboardPersistenceState::Unavailable:
        return QStringLiteral("unavailable");
    case ClipboardPersistenceState::Cancelled:
        return QStringLiteral("cancelled");
    case ClipboardPersistenceState::DeniedOrLocked:
        return QStringLiteral("locked");
    case ClipboardPersistenceState::MissingKey:
        return QStringLiteral("missing-key");
    case ClipboardPersistenceState::RecoveryRequired:
        return QStringLiteral("recovery");
    case ClipboardPersistenceState::BackendError:
        return QStringLiteral("error");
    }
    return QStringLiteral("error");
}
} // namespace

// Everything Noctalia's Application wires for the clipboard, on one thread:
// its own Wayland connection (seat, data control, virtual keyboard), the
// secret store and storage key, the clipboard service, and the poll loop
// over all of them (application_poll_sources.cpp's job in Noctalia).
struct Clipboard::Worker {
    QPointer<Clipboard> owner;

    wl_display *display = nullptr;
    wl_registry *registry = nullptr;
    wl_seat *seat = nullptr;
    void *dataManager = nullptr;
    const DataControlOps *ops = nullptr;
    zwp_virtual_keyboard_manager_v1 *vkManager = nullptr;

    security::SecretStore secretStore;
    security::StorageKeyProvider keys{secretStore};
    ClipboardService clipboard{keys};
    ClipboardPollSource clipboardPoll{clipboard};
    VirtualKeyboardService keyboard;

    int wake = -1;
    std::atomic<bool> stop{false};
    std::mutex queueMutex;
    std::deque<std::function<void(Worker &)>> queue;

    static void global(void *data, wl_registry *reg, uint32_t name, const char *iface, uint32_t version) {
        auto *w = static_cast<Worker *>(data);
        if (strcmp(iface, wl_seat_interface.name) == 0 && !w->seat) {
            w->seat = static_cast<wl_seat *>(wl_registry_bind(reg, name, &wl_seat_interface, std::min(version, 5u)));
        } else if (strcmp(iface, extDataControlOps()->managerInterfaceName) == 0) {
            // ext-data-control first (Noctalia's preference), wlr as a fallback.
            if (w->dataManager && w->ops != extDataControlOps())
                w->ops->destroyManager(w->dataManager);
            if (!w->dataManager || w->ops != extDataControlOps()) {
                w->dataManager = extDataControlOps()->bindManager(reg, name, version);
                w->ops = extDataControlOps();
            }
        } else if (strcmp(iface, wlrDataControlOps()->managerInterfaceName) == 0 && !w->dataManager) {
            w->dataManager = wlrDataControlOps()->bindManager(reg, name, version);
            w->ops = wlrDataControlOps();
        } else if (strcmp(iface, zwp_virtual_keyboard_manager_v1_interface.name) == 0) {
            w->vkManager = static_cast<zwp_virtual_keyboard_manager_v1 *>(
                wl_registry_bind(reg, name, &zwp_virtual_keyboard_manager_v1_interface, 1));
        }
    }
    static void globalRemove(void *, wl_registry *, uint32_t) {}
    static constexpr wl_registry_listener registryListener{global, globalRemove};

    // The history as QML sees it, sent to the GUI thread.
    void publish() {
        QVariantList list;
        for (const auto &e : clipboard.history()) {
            QVariantMap m;
            m.insert(QStringLiteral("id"), QString::fromStdString(e.storageId));
            m.insert(QStringLiteral("preview"), QString::fromStdString(e.textPreview));
            m.insert(QStringLiteral("mime"), QString::fromStdString(e.dataMimeType));
            m.insert(QStringLiteral("image"), e.isImage());
            m.insert(QStringLiteral("pinned"), e.pinned);
            m.insert(QStringLiteral("time"), double(std::chrono::duration_cast<std::chrono::milliseconds>(e.capturedAt.time_since_epoch()).count()));
            m.insert(QStringLiteral("bytes"), double(e.byteSize));
            list.push_back(m);
        }
        const QString state = stateName(clipboard.persistenceState());
        const bool available = clipboard.isAvailable();
        QPointer<Clipboard> o = owner;
        QMetaObject::invokeMethod(o.data(), [o, list, state, available] {
            if (o)
                o->publish(list, state, available);
        }, Qt::QueuedConnection);
    }

    bool start() {
        display = wl_display_connect(nullptr);
        if (!display)
            return false;
        registry = wl_display_get_registry(display);
        wl_registry_add_listener(registry, &registryListener, this);
        wl_display_roundtrip(display);
        wake = eventfd(0, EFD_CLOEXEC | EFD_NONBLOCK);

        if (!security::initializeSecurityPrimitives())
            qWarning() << "nafeel: clipboard: libsodium failed to initialise; the history won't be kept";
        keys.setChangeCallback([this] {
            clipboard.syncPersistence();
            publish();
        });
        keys.configure(StorageKeySource::SecretService, std::string(), clipboard.hasEncryptedPersistence());

        clipboard.setHistoryRetentionEnabled(true);
        clipboard.setKeepFromClosedApps(true);
        clipboard.setMaxHistoryEntries(100);
        clipboard.setChangeCallback([this] { publish(); });
        clipboard.setPersistenceChangeCallback([this] { publish(); });
        if (dataManager && seat)
            clipboard.bind(dataManager, ops, seat);
        else
            qWarning() << "nafeel: clipboard: the compositor offers no data-control protocol";
        if (vkManager && seat)
            keyboard.bind(vkManager, seat);
        wl_display_flush(display);
        publish();
        return true;
    }

    void run() {
        std::vector<pollfd> fds;
        while (!stop) {
            // Commands from the GUI thread.
            std::deque<std::function<void(Worker &)>> pending;
            {
                std::lock_guard lock(queueMutex);
                pending.swap(queue);
            }
            for (auto &fn : pending)
                fn(*this);

            while (wl_display_prepare_read(display) != 0)
                wl_display_dispatch_pending(display);
            wl_display_flush(display);

            fds.clear();
            fds.push_back({wl_display_get_fd(display), POLLIN, 0});
            fds.push_back({wake, POLLIN, 0});
            const std::size_t secretStart = secretStore.addPollFds(fds);
            const std::size_t clipStart = clipboardPoll.addPollFds(fds);
            int timeout = -1;
            for (int t : {secretStore.pollTimeoutMs(), clipboardPoll.pollTimeoutMs()})
                if (t >= 0 && (timeout < 0 || t < timeout))
                    timeout = t;

            const int r = poll(fds.data(), fds.size(), timeout);
            if (r < 0 && errno != EINTR) {
                wl_display_cancel_read(display);
                break;
            }
            if (r > 0 && (fds[0].revents & POLLIN)) {
                if (wl_display_read_events(display) < 0)
                    break;
            } else {
                wl_display_cancel_read(display);
            }
            wl_display_dispatch_pending(display);
            if (fds[1].revents & POLLIN) {
                uint64_t n;
                (void)!read(wake, &n, sizeof(n));
            }
            secretStore.dispatch(fds, secretStart);
            clipboardPoll.dispatch(fds, clipStart);
            wl_display_flush(display);
        }
    }

    void post(std::function<void(Worker &)> fn) {
        {
            std::lock_guard lock(queueMutex);
            queue.push_back(std::move(fn));
        }
        const uint64_t one = 1;
        (void)!write(wake, &one, sizeof(one));
    }

    ~Worker() {
        clipboard.cleanup();
        keyboard.cleanup();
        if (display) {
            wl_display_flush(display);
            wl_display_disconnect(display);
        }
        if (wake >= 0)
            close(wake);
    }
};

Clipboard::Clipboard(QObject *parent) : QObject(parent), m_worker(std::make_unique<Worker>()) {
    m_worker->owner = this;
    Worker *w = m_worker.get();
    std::promise<bool> started;
    auto ready = started.get_future();
    m_thread = std::thread([w, &started] {
        const bool ok = w->start();
        started.set_value(ok);
        if (ok)
            w->run();
    });
    if (!ready.get())
        qWarning() << "nafeel: clipboard: no Wayland display";
}

Clipboard::~Clipboard() {
    if (m_worker) {
        m_worker->stop = true;
        m_worker->post([](Worker &) {});
    }
    if (m_thread.joinable())
        m_thread.join();
}

void Clipboard::post(std::function<void(Worker &)> fn) {
    if (m_worker && m_worker->wake >= 0)
        m_worker->post(std::move(fn));
}

template <typename T> T Clipboard::call(std::function<T(Worker &)> fn, T fallback) {
    if (!m_worker || m_worker->wake < 0)
        return fallback;
    auto promise = std::make_shared<std::promise<T>>();
    auto future = promise->get_future();
    m_worker->post([fn, promise](Worker &w) { promise->set_value(fn(w)); });
    if (future.wait_for(std::chrono::seconds(2)) != std::future_status::ready)
        return fallback;
    return future.get();
}

void Clipboard::publish(QVariantList entries, QString state, bool available) {
    m_entries = std::move(entries);
    emit entriesChanged();
    if (state != m_state || available != m_available) {
        m_state = state;
        m_available = available;
        emit stateChanged();
    }
}

void Clipboard::activate(int index, bool paste, int pasteDelay) {
    post([index, paste, pasteDelay](Worker &w) {
        const auto &h = w.clipboard.history();
        if (index < 0 || std::size_t(index) >= h.size() || !w.clipboard.ensureEntryLoaded(std::size_t(index)))
            return;
        // As Noctalia's panel does: pinned entries are only copied, others
        // also move to the top.
        const ClipboardEntry entry = h[std::size_t(index)];
        if (!entry.pinned)
            w.clipboard.promoteEntry(std::size_t(index));
        w.clipboard.copyEntry(entry);
        w.publish();
        if (!paste)
            return;
        // Auto-paste "auto": Ctrl+Shift+V for text (no formatting), Ctrl+V
        // for images; once the panel has let go of the keyboard.
        const bool image = entry.isImage();
        QPointer<Clipboard> o = w.owner;
        QMetaObject::invokeMethod(o.data(), [o, image, pasteDelay] {
            if (!o)
                return;
            QTimer::singleShot(pasteDelay, o.data(), [o, image] {
                if (o)
                    o->post([image](Worker &w2) {
                        (void)w2.keyboard.sendPasteShortcut(image ? VirtualPasteShortcut::CtrlV : VirtualPasteShortcut::CtrlShiftV);
                    });
            });
        }, Qt::QueuedConnection);
    });
}

void Clipboard::togglePin(int index) {
    post([index](Worker &w) {
        const auto &h = w.clipboard.history();
        if (index >= 0 && std::size_t(index) < h.size())
            w.clipboard.setEntryPinned(std::size_t(index), !h[std::size_t(index)].pinned);
        w.publish();
    });
}

void Clipboard::remove(int index) {
    post([index](Worker &w) {
        if (index >= 0)
            w.clipboard.removeHistoryEntry(std::size_t(index));
        w.publish();
    });
}

void Clipboard::clearUnpinned() {
    post([](Worker &w) {
        w.clipboard.clearUnpinnedHistory();
        w.publish();
    });
}

void Clipboard::clearAll() {
    post([](Worker &w) {
        w.clipboard.clearHistory();
        w.publish();
    });
}

void Clipboard::copyText(const QString &text) {
    const std::string s = text.toStdString();
    post([s](Worker &w) { w.clipboard.copyText(s); });
}

void Clipboard::copyImageFile(const QString &path) {
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly))
        return;
    const QByteArray bytes = f.readAll();
    std::vector<std::uint8_t> png(bytes.begin(), bytes.end());
    post([png = std::move(png)](Worker &w) mutable { w.clipboard.copyImagePng(std::move(png)); });
}

void Clipboard::retry() {
    post([](Worker &w) {
        w.keys.retry();
        w.clipboard.retryPersistence();
        w.publish();
    });
}

QString Clipboard::text(int index) {
    return call<QString>([index](Worker &w) -> QString {
        const auto &h = w.clipboard.history();
        if (index < 0 || std::size_t(index) >= h.size() || h[std::size_t(index)].isImage() ||
            !w.clipboard.ensureEntryLoaded(std::size_t(index)))
            return {};
        const auto &d = h[std::size_t(index)].data;
        return QString::fromUtf8(reinterpret_cast<const char *>(d.data()), qsizetype(d.size()));
    }, QString());
}

QString Clipboard::imageUrl(int index) {
    return call<QString>([index](Worker &w) -> QString {
        if (index < 0)
            return {};
        const auto uri = w.clipboard.imageDataUri(std::size_t(index));
        return uri ? QString::fromStdString(*uri) : QString();
    }, QString());
}
