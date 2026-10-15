#pragma once

#include <QObject>
#include <QtQml/qqmlregistration.h>

#include <malloc.h>
#include <thread>

// Hands memory the shell has freed back to the system. glibc keeps what's
// freed in its arenas (one per thread that allocated): a live wallpaper's
// decoder let go of tens of MB that stayed counted against the shell until
// something reused them. malloc_trim walks every arena; it runs on a thread
// of its own (it takes each arena's lock and madvises, a few ms) so the GUI
// thread never waits for it.
class Memory : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    using QObject::QObject;

    Q_INVOKABLE void trim() const {
        std::thread([] { malloc_trim(0); }).detach();
    }
};
