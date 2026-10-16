#pragma once

#include <mutex>

extern "C" {
#include <libavutil/buffer.h>
#include <libavutil/hwcontext.h>
}

// One VA-API device for the whole process. Each player making its own
// (av_hwdevice_ctx_create) loaded the VA driver again for it: ~5-9 MB of
// driver state each (the desktop wallpaper's, the lock's and the picker
// preview's, all at once while locked). They share this one, made when the
// first needs it and let go when the last does (a static desktop holds none).
// libva serialises calls on a display itself (as ffmpeg's own streams
// sharing a device rely on).
class VaapiDevice {
public:
    // A new reference to the shared device (made if there is none), or null.
    static AVBufferRef *acquire() {
        std::lock_guard<std::mutex> lock(mutex());
        if (!device() && av_hwdevice_ctx_create(&device(), AV_HWDEVICE_TYPE_VAAPI, nullptr, nullptr, 0) < 0)
            device() = nullptr;
        if (!device())
            return nullptr;
        users()++;
        return av_buffer_ref(device());
    }

    // Lets go of a reference from acquire(); the device goes with the last.
    static void release(AVBufferRef **ref) {
        if (!ref || !*ref)
            return;
        av_buffer_unref(ref);
        std::lock_guard<std::mutex> lock(mutex());
        if (--users() <= 0 && device()) {
            av_buffer_unref(&device());
            users() = 0;
        }
    }

private:
    static std::mutex &mutex() {
        static std::mutex m;
        return m;
    }
    static AVBufferRef *&device() {
        static AVBufferRef *d = nullptr;
        return d;
    }
    static int &users() {
        static int n = 0;
        return n;
    }
};
