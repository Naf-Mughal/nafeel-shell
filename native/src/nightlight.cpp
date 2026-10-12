#include "nightlight.h"

#include <QDebug>
#include <QSocketNotifier>

#include <algorithm>
#include <cerrno>
#include <cmath>
#include <cstring>
#include <sys/mman.h>
#include <unistd.h>

#include <wayland-client.h>

#include "wlr-gamma-control-unstable-v1-client-protocol.h"

namespace {
constexpr int kDay = 6500;
// One upload per ~50 K of swing (Noctalia's kTargetStepKelvin).
constexpr int kStepKelvin = 50;

struct Rgb {
    double r = 1, g = 1, b = 1;
};

// Noctalia's GammaService::kelvinToRgb.
Rgb kelvinToRgb(int kelvin) {
    const double temp = std::clamp(kelvin, 1000, 10000) / 100.0;
    Rgb mul;
    if (temp <= 66.0) {
        mul.r = 1.0;
        mul.g = std::clamp((99.4708025861 * std::log(temp) - 161.1195681661) / 255.0, 0.0, 1.0);
        mul.b = temp <= 19.0 ? 0.0 : std::clamp((138.5177312231 * std::log(temp - 10.0) - 305.0447927307) / 255.0, 0.0, 1.0);
    } else {
        mul.r = std::clamp(329.698727446 * std::pow(temp - 60.0, -0.1332047592) / 255.0, 0.0, 1.0);
        mul.g = std::clamp(288.1221695283 * std::pow(temp - 60.0, -0.0755148492) / 255.0, 0.0, 1.0);
        mul.b = 1.0;
    }
    return mul;
}

// Noctalia's GammaService::fillGammaRamp.
void fillRamp(uint16_t *ramp, uint32_t size, const Rgb &mul) {
    const double scale = 65535.0 / double(size - 1);
    for (uint32_t i = 0; i < size; ++i) {
        const double base = i * scale;
        ramp[i] = uint16_t(std::clamp(mul.r * base, 0.0, 65535.0));
        ramp[size + i] = uint16_t(std::clamp(mul.g * base, 0.0, 65535.0));
        ramp[2 * size + i] = uint16_t(std::clamp(mul.b * base, 0.0, 65535.0));
    }
}
} // namespace

struct NightLightListeners {
    static void global(void *data, wl_registry *reg, uint32_t name, const char *iface, uint32_t version) {
        auto *n = static_cast<NightLight *>(data);
        if (strcmp(iface, zwlr_gamma_control_manager_v1_interface.name) == 0) {
            n->m_manager = static_cast<zwlr_gamma_control_manager_v1 *>(
                wl_registry_bind(reg, name, &zwlr_gamma_control_manager_v1_interface, 1));
        } else if (strcmp(iface, wl_output_interface.name) == 0) {
            auto *o = new NightLight::Output;
            o->owner = n;
            o->name = name;
            o->output = static_cast<wl_output *>(wl_registry_bind(reg, name, &wl_output_interface, 1));
            n->m_outputs.push_back(o);
            if (n->m_active || n->m_shown >= 0)
                n->ensureControls();
        }
    }
    static void globalRemove(void *data, wl_registry *, uint32_t name) {
        auto *n = static_cast<NightLight *>(data);
        auto it = std::find_if(n->m_outputs.begin(), n->m_outputs.end(), [name](auto *o) { return o->name == name; });
        if (it == n->m_outputs.end())
            return;
        auto *o = *it;
        if (o->control)
            zwlr_gamma_control_v1_destroy(o->control);
        wl_output_destroy(o->output);
        delete o;
        n->m_outputs.erase(it);
    }
    static constexpr wl_registry_listener registry{global, globalRemove};

    static void gammaSize(void *data, zwlr_gamma_control_v1 *, uint32_t size) {
        auto *o = static_cast<NightLight::Output *>(data);
        o->size = size;
        if (o->owner->m_shown >= 0)
            o->owner->apply(*o, o->owner->m_shown);
    }
    static void failed(void *data, zwlr_gamma_control_v1 *) {
        auto *o = static_cast<NightLight::Output *>(data);
        qWarning() << "nafeel: night light: gamma control refused for an output (another program holds it?)";
        zwlr_gamma_control_v1_destroy(o->control);
        o->control = nullptr;
        o->size = 0;
        // Try again in a moment: the holder (Noctalia's own night light, say)
        // may let go.
        auto *n = o->owner;
        QTimer::singleShot(2000, n, [n] {
            if (n->m_active)
                n->ensureControls();
        });
    }
    static constexpr zwlr_gamma_control_v1_listener control{gammaSize, failed};
};

NightLight::NightLight(QObject *parent) : QObject(parent) {
    m_timer.setInterval(16);
    connect(&m_timer, &QTimer::timeout, this, &NightLight::tick);

    m_display = wl_display_connect(nullptr);
    if (!m_display)
        return;
    m_registry = wl_display_get_registry(m_display);
    wl_registry_add_listener(m_registry, &NightLightListeners::registry, this);
    wl_display_roundtrip(m_display);
    if (!m_manager)
        qWarning() << "nafeel: night light: the compositor has no wlr-gamma-control";
    m_notifier = new QSocketNotifier(wl_display_get_fd(m_display), QSocketNotifier::Read, this);
    connect(m_notifier, &QSocketNotifier::activated, this, &NightLight::read);
}

NightLight::~NightLight() {
    releaseControls();
    for (auto *o : m_outputs) {
        wl_output_destroy(o->output);
        delete o;
    }
    if (m_display) {
        wl_display_flush(m_display);
        wl_display_disconnect(m_display);
    }
}

void NightLight::read() {
    while (wl_display_prepare_read(m_display) != 0)
        wl_display_dispatch_pending(m_display);
    if (wl_display_read_events(m_display) < 0 && errno != EAGAIN) {
        m_notifier->setEnabled(false);
        return;
    }
    wl_display_dispatch_pending(m_display);
    flush();
}

void NightLight::flush() {
    if (m_display)
        wl_display_flush(m_display);
}

void NightLight::setActive(bool on) {
    if (on == m_active)
        return;
    m_active = on;
    emit activeChanged();
    retarget();
}

void NightLight::setTemperature(int k) {
    k = std::clamp(k, 1000, 10000);
    if (k == m_temperature)
        return;
    m_temperature = k;
    emit temperatureChanged();
    if (m_active)
        retarget();
}

void NightLight::ensureControls() {
    if (!m_manager)
        return;
    for (auto *o : m_outputs) {
        if (o->control)
            continue;
        o->control = zwlr_gamma_control_manager_v1_get_gamma_control(m_manager, o->output);
        zwlr_gamma_control_v1_add_listener(o->control, &NightLightListeners::control, o);
    }
    flush();
}

void NightLight::releaseControls() {
    for (auto *o : m_outputs) {
        if (o->control) {
            zwlr_gamma_control_v1_destroy(o->control);
            o->control = nullptr;
            o->size = 0;
        }
    }
    m_shown = -1;
    flush();
}

void NightLight::apply(Output &o, int kelvin) {
    if (!o.control || o.size == 0)
        return;
    const size_t bytes = 3 * o.size * sizeof(uint16_t);
    const int fd = memfd_create("nafeel-gamma", MFD_CLOEXEC);
    if (fd < 0)
        return;
    if (ftruncate(fd, off_t(bytes)) < 0) {
        close(fd);
        return;
    }
    auto *data = static_cast<uint16_t *>(mmap(nullptr, bytes, PROT_WRITE, MAP_SHARED, fd, 0));
    if (data == MAP_FAILED) {
        close(fd);
        return;
    }
    fillRamp(data, o.size, kelvinToRgb(kelvin));
    munmap(data, bytes);
    zwlr_gamma_control_v1_set_gamma(o.control, fd);
    close(fd);
}

void NightLight::applyAll(int kelvin) {
    m_shown = kelvin;
    for (auto *o : m_outputs)
        apply(*o, kelvin);
    flush();
}

void NightLight::retarget() {
    if (!m_manager)
        return;
    m_target = m_active ? m_temperature : kDay;
    if (m_active)
        ensureControls();
    if (!m_timer.isActive())
        m_timer.start();
}

void NightLight::tick() {
    // Ease toward the target, at most one upload per ~50 K of change.
    const double swing = std::abs(double(m_target) - m_current);
    const double perTick = std::max(double(kStepKelvin) / 4.0, swing / std::max(1.0, m_fade / 16.0) * 1.0);
    if (swing <= perTick) {
        m_current = m_target;
    } else {
        m_current += (m_target > m_current ? 1 : -1) * perTick;
    }
    const int k = int(std::lround(m_current));
    if (m_shown < 0 || std::abs(k - m_shown) >= kStepKelvin || k == m_target)
        applyAll(k);
    if (k == m_target) {
        m_timer.stop();
        // Back at day: let go, and the compositor restores the original gamma.
        if (!m_active && m_target == kDay)
            releaseControls();
    }
}
