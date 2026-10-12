#pragma once

#include <QObject>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

#include <vector>

struct wl_display;
struct wl_output;
struct wl_registry;
struct zwlr_gamma_control_manager_v1;
struct zwlr_gamma_control_v1;
class QSocketNotifier;

// Night light: a warmer colour temperature on every output, through
// wlr-gamma-control. Ported from Noctalia's GammaService
// (src/system/gamma_service.cpp, MIT, Copyright (c) 2026 noctalia-dev): the
// same Kelvin -> RGB curve and per-output ramps, a fade in ~50 K steps.
// Turning it off fades back to 6500 K and lets the controls go, so the
// compositor restores the original gamma.
class NightLight : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(int temperature READ temperature WRITE setTemperature NOTIFY temperatureChanged)
    // How long the fade takes (ms).
    Q_PROPERTY(int fade MEMBER m_fade NOTIFY fadeChanged)
    // Whether the compositor can do it at all.
    Q_PROPERTY(bool available READ available CONSTANT)

public:
    explicit NightLight(QObject *parent = nullptr);
    ~NightLight() override;

    bool active() const { return m_active; }
    void setActive(bool on);
    int temperature() const { return m_temperature; }
    void setTemperature(int k);
    bool available() const { return m_manager != nullptr; }

signals:
    void activeChanged();
    void temperatureChanged();
    void fadeChanged();

private:
    friend struct NightLightListeners;

    struct Output {
        NightLight *owner = nullptr;
        wl_output *output = nullptr;
        uint32_t name = 0;
        zwlr_gamma_control_v1 *control = nullptr;
        uint32_t size = 0;
    };

    void read();
    void flush();
    void ensureControls();
    void releaseControls();
    void apply(Output &o, int kelvin);
    void applyAll(int kelvin);
    void retarget();
    void tick();

    wl_display *m_display = nullptr;
    wl_registry *m_registry = nullptr;
    QSocketNotifier *m_notifier = nullptr;
    zwlr_gamma_control_manager_v1 *m_manager = nullptr;
    std::vector<Output *> m_outputs;

    bool m_active = false;
    int m_temperature = 4000;
    int m_fade = 900;
    // The temperature shown now, and where it's heading.
    double m_current = 6500;
    int m_target = 6500;
    int m_shown = -1;
    QTimer m_timer;
};
