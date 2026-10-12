#version 440

// Ink soaking into paper: the content appears from `origin` (the corner or
// bar side a panel grows from) outward as `progress` goes 0 -> 1, behind an
// organic, noisy front rather than a straight wipe or a plain fade.
//
// Rebuild after editing:  /usr/lib/qt6/bin/qsb --qt6 -o soak.frag.qsb soak.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;     // 0 = nothing, 1 = all of it
    vec2 origin;        // where it soaks from, 0..1 in the item
    vec2 size;          // item size in px
} ubuf;

layout(binding = 1) uniform sampler2D source;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 3; i++) {
        v += a * noise(p);
        p = p * 2.07 + 7.3;
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 px = qt_TexCoord0 * ubuf.size;
    vec2 o = ubuf.origin * ubuf.size;
    // Distance from the origin, over the farthest point's.
    vec2 far = max(o, ubuf.size - o);
    float d = length(px - o) / max(length(far), 1.0);
    // The front: blotchy (fbm), reaching past the far corner at progress 1.
    float n = fbm(px / 70.0) - 0.5;
    float front = ubuf.progress * 1.3 - 0.15;
    float a = 1.0 - smoothstep(front - 0.14, front, d + n * 0.3);
    fragColor = texture(source, qt_TexCoord0) * a * ubuf.qt_Opacity;
}
