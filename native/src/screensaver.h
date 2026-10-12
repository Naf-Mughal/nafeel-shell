#pragma once

#include <QDBusContext>
#include <QHash>
#include <QObject>
#include <QString>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

class QDBusServiceWatcher;

// The org.freedesktop.ScreenSaver D-Bus service: apps that keep the screen
// awake over D-Bus (video players, some Electron apps, Steam, games) call
// Inhibit / UnInhibit here. An app's inhibitors go with it when it leaves
// the bus. The shell's idle holds off while `inhibited`.
//
// The name is queued: while another program holds it (Noctalia, before the
// cut-over) the shell waits in line and takes it as soon as it's free.
// Served at /org/freedesktop/ScreenSaver and /ScreenSaver (KDE's path).
class ScreenSaver : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool inhibited READ inhibited NOTIFY changed)
    Q_PROPERTY(bool owned READ owned NOTIFY ownedChanged)
    // [{ cookie, app, reason }]
    Q_PROPERTY(QVariantList inhibitors READ inhibitors NOTIFY changed)

public:
    explicit ScreenSaver(QObject* parent = nullptr);

    bool inhibited() const { return !m_inhibitors.isEmpty(); }
    bool owned() const { return m_owned; }
    QVariantList inhibitors() const;

    uint inhibit(const QString& app, const QString& reason, const QString& sender);
    void unInhibit(uint cookie);

signals:
    void changed();
    void ownedChanged();

private:
    struct Inhibitor {
        QString app;
        QString reason;
        QString sender;
    };

    void dropSender(const QString& sender);

    QHash<uint, Inhibitor> m_inhibitors;
    uint m_next = 1;
    bool m_owned = false;
    QDBusServiceWatcher* m_watcher = nullptr;
};

// The D-Bus face of ScreenSaver (one per object path).
class ScreenSaverAdaptor : public QObject, protected QDBusContext {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.ScreenSaver")

public:
    explicit ScreenSaverAdaptor(ScreenSaver* service);

public slots:
    Q_SCRIPTABLE uint Inhibit(const QString& application, const QString& reason);
    Q_SCRIPTABLE void UnInhibit(uint cookie);
    Q_SCRIPTABLE bool GetActive();

signals:
    Q_SCRIPTABLE void ActiveChanged(bool active);

private:
    ScreenSaver* m_service;
};
