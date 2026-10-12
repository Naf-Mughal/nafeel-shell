#version 440

// The shell's ink transition, on a still of how things were: the old look
// gives way from `origin` outward behind a blotchy, wet front (the soak's
// noise), with a thin dark tide line where ink meets paper, so the new look
// seems to soak through rather than wipe in.
//
// Rebuild after editing:  /usr/lib/qt6/bin/qsb --qt6 -o inkwipe.frag.qsb inkwipe.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;     // 0 = all old, 1 = all new
    vec2 origin;        // where the ink lands, 0..1 in the item
    vec2 size;          // item size in px
    vec4 tide;          // the tide line's colour (alpha = strength)
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
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p = p * 2.07 + 7.3;
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 px = qt_TexCoord0 * ubuf.size;
    vec2 o = ubuf.origin * ubuf.size;
    vec2 far = max(o, ubuf.size - o);
    float d = length(px - o) / max(length(far), 1.0);
    // Two scales of blotch: the soak's wandering edge and fine fibres.
    float n = (fbm(px / 90.0) - 0.5) * 0.34 + (noise(px / 6.0) - 0.5) * 0.03;
    float front = ubuf.progress * 1.35 - 0.12;
    float x = d + n - front;
    // 1 where the old look still shows, 0 where the ink has soaked through.
    float keep = smoothstep(-0.06, 0.0, x);
    // The tide line: just behind the front, darker, fading as it dries.
    float line = exp(-pow((x + 0.012) / 0.012, 2.0)) * (1.0 - ubuf.progress * 0.6);
    vec4 was = texture(source, qt_TexCoord0);
    vec4 old = was * keep;
    // Only where the shell drew something (the frame's window is otherwise
    // clear over your apps): no line across windows.
    vec4 t = vec4(ubuf.tide.rgb, 1.0) * ubuf.tide.a * line * was.a;
    fragColor = (old + t * (1.0 - old.a)) * ubuf.qt_Opacity;
}
