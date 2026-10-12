#pragma once

#include <QGuiApplication>
#include <QObject>
#include <QtQml/qqmlregistration.h>

// The modifiers held right now, from the compositor's last word on them (not
// from the last key event QML saw): a surface that just took the keyboard can
// tell whether Alt is still down.
class Keyboard : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    using QObject::QObject;

    Q_INVOKABLE int modifiers() const { return int(QGuiApplication::queryKeyboardModifiers()); }
};
