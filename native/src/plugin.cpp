#include <QtQml/QQmlEngine>
#include <QtQml/QQmlEngineExtensionPlugin>

#include "stillimage.h"

extern void qml_register_types_Nafeel();
Q_GHS_KEEP_REFERENCE(qml_register_types_Nafeel)

class NafeelPlugin : public QQmlEngineExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlEngineExtensionInterface_iid)

public:
    NafeelPlugin(QObject *parent = nullptr) : QQmlEngineExtensionPlugin(parent) {
        volatile auto registration = &qml_register_types_Nafeel;
        Q_UNUSED(registration)
    }

    // image://still/<fit|crop>/<path>: pictures held only as textures.
    void initializeEngine(QQmlEngine *engine, const char *uri) override {
        Q_UNUSED(uri)
        if (!engine->imageProvider(QStringLiteral("still")))
            engine->addImageProvider(QStringLiteral("still"), new StillProvider);
    }
};

#include "plugin.moc"
