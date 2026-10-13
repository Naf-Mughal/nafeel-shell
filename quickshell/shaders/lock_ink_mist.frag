#version 440

// The lock backdrop's drifting mist banks, alone: rendered small (a quarter
// of the screen each way) into a texture the backdrop samples, smooth under
// bilinear filtering. Mist is low-frequency and slow; worked out for every
// screen pixel it was most of the lock's ~13 ms a frame on this GPU.
//
// Rebuild after editing:  /usr/lib/qt6/bin/qsb --qt6 -o lock_ink_mist.frag.qsb lock_ink_mist.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
} ubuf;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p = p * 2.03 + vec2(17.3, 9.1);
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float t = ubuf.time;
    float m = fbm(uv * vec2(2.4, 5.2) + vec2(t * 0.018, t * 0.004));
    float m2 = fbm(uv * vec2(4.8, 9.0) - vec2(t * 0.011, 0.0));
    float bank = smoothstep(0.45, 0.85, m * 0.7 + m2 * 0.3);
    float depth = 0.1 + 0.5 * smoothstep(0.3, 1.0, uv.y);
    fragColor = vec4(bank * depth, 0.0, 0.0, 1.0);
}
