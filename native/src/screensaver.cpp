#include "screensaver.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusServiceWatcher>
#include <QLoggingCategory>

namespace {
Q_LOGGING_CATEGORY(lcSaver, "nafeel.screensaver", QtInfoMsg)

constexpr auto kName = "org.freedesktop.ScreenSaver";
} // namespace

ScreenSaver::ScreenSaver(QObject* parent) : QObject(parent) {
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        qCWarning(lcSaver) << "no session bus";
        return;
    }

    // Both paths apps use.
    for (const char* path : {"/org/freedesktop/ScreenSaver", "/ScreenSaver"}) {
        auto* adaptor = new ScreenSaverAdaptor(this);
        // A reload makes a new one while the old one still serves: take over.
        bus.unregisterObject(QString::fromLatin1(path));
        if (!bus.registerObject(QString::fromLatin1(path), adaptor, QDBusConnection::ExportScriptableSlots | QDBusConnection::ExportScriptableSignals))
            qCWarning(lcSaver) << "can't serve" << path;
    }

    // An app that leaves the bus takes its inhibitors with it.
    m_watcher = new QDBusServiceWatcher(this);
    m_watcher->setConnection(bus);
    m_watcher->setWatchMode(QDBusServiceWatcher::WatchForUnregistration);
    connect(m_watcher, &QDBusServiceWatcher::serviceUnregistered, this, &ScreenSaver::dropSender);

    // Queued: whoever holds the name now (Noctalia, before the cut-over)
    // keeps it; the shell gets it the moment it's free (the owner changes
    // straight to us).
    QDBusConnectionInterface* iface = bus.interface();
    auto* ownerWatch = new QDBusServiceWatcher(QString::fromLatin1(kName), bus, QDBusServiceWatcher::WatchForOwnerChange, this);
    connect(ownerWatch, &QDBusServiceWatcher::serviceOwnerChanged, this, [this](const QString&, const QString&, const QString& owner) {
        if (!m_owned && owner == QDBusConnection::sessionBus().baseService()) {
            m_owned = true;
            qCInfo(lcSaver) << "serving" << kName;
            emit ownedChanged();
        }
    });
    const auto reply = iface->registerService(QString::fromLatin1(kName), QDBusConnectionInterface::QueueService, QDBusConnectionInterface::AllowReplacement);
    if (reply.isValid() && reply.value() == QDBusConnectionInterface::ServiceRegistered) {
        m_owned = true;
        qCInfo(lcSaver) << "serving" << kName;
    } else if (reply.isValid() && reply.value() == QDBusConnectionInterface::ServiceQueued) {
        qCInfo(lcSaver) << kName << "is taken; waiting in line for it";
    } else {
        qCWarning(lcSaver) << "can't register" << kName << reply.error().message();
    }
}

QVariantList ScreenSaver::inhibitors() const {
    QVariantList out;
    for (auto it = m_inhibitors.cbegin(); it != m_inhibitors.cend(); ++it)
        out.append(QVariantMap{{QStringLiteral("cookie"), it.key()}, {QStringLiteral("app"), it->app}, {QStringLiteral("reason"), it->reason}});
    return out;
}

uint ScreenSaver::inhibit(const QString& app, const QString& reason, const QString& sender) {
    const uint cookie = m_next++;
    m_inhibitors.insert(cookie, {app, reason, sender});
    if (!sender.isEmpty())
        m_watcher->addWatchedService(sender);
    qCInfo(lcSaver) << "inhibited by" << app << "-" << reason << "(" << cookie << ")";
    emit changed();
    return cookie;
}

void ScreenSaver::unInhibit(uint cookie) {
    if (m_inhibitors.remove(cookie) > 0) {
        qCInfo(lcSaver) << "released" << cookie;
        emit changed();
    }
}

void ScreenSaver::dropSender(const QString& sender) {
    bool any = false;
    for (auto it = m_inhibitors.begin(); it != m_inhibitors.end();) {
        if (it->sender == sender) {
            it = m_inhibitors.erase(it);
            any = true;
        } else {
            ++it;
        }
    }
    m_watcher->removeWatchedService(sender);
    if (any) {
        qCInfo(lcSaver) << "released everything from" << sender << "(it left the bus)";
        emit changed();
    }
}

ScreenSaverAdaptor::ScreenSaverAdaptor(ScreenSaver* service) : QObject(service), m_service(service) {}

uint ScreenSaverAdaptor::Inhibit(const QString& application, const QString& reason) {
    return m_service->inhibit(application, reason, calledFromDBus() ? message().service() : QString());
}

void ScreenSaverAdaptor::UnInhibit(uint cookie) {
    m_service->unInhibit(cookie);
}

bool ScreenSaverAdaptor::GetActive() {
    return false;
}
