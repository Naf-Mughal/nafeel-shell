#include <QtQml/QQmlEngineExtensionPlugin>

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
};

#include "plugin.moc"
