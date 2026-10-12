#version 440

// Inside an open drawer, behind its content (fully immersive mode): a slow
// ink mist drifting across, and a few spirit motes rising and twinkling, in
// the cave-abode manner. Transparent everywhere else.
//
// Rebuild after editing:  /usr/lib/qt6/bin/qsb --qt6 -o mist.frag.qsb mist.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;      // px
    float time;     // s
    vec4 mist;      // mist tint
    vec4 mote;      // mote colour
    float strength; // 0..1
} ubuf;

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
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p = p * 2.02 + 7.3;
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 p = qt_TexCoord0 * ubuf.size;
    float t = ubuf.time;

    // Mist: domain-warped fbm drifting slowly to the right, densest low down.
    vec2 q = p / 220.0;
    vec2 warp = vec2(fbm(q + vec2(t * 0.02, 0.0)), fbm(q + vec2(5.2, t * 0.015)));
    float m = fbm(q * 1.4 + warp * 1.6 + vec2(t * 0.035, 0.0));
    m = smoothstep(0.45, 0.9, m) * (0.55 + 0.45 * qt_TexCoord0.y);
    float alpha = m * 0.09 * ubuf.strength;
    vec3 col = ubuf.mist.rgb;

    // Motes: one per 90px cell at most, rising and twinkling.
    vec2 cellSize = vec2(90.0);
    vec2 drift = vec2(sin(t * 0.3) * 6.0, -t * 9.0);
    vec2 cp = (p - drift) / cellSize;
    vec2 cell = floor(cp);
    float h = hash(cell);
    if (h > 0.72) {
        vec2 centre = (cell + vec2(hash(cell + 3.1), hash(cell + 7.7))) * cellSize + drift;
        float d = length(p - centre);
        float twinkle = 0.5 + 0.5 * sin(t * (1.5 + h * 2.0) + h * 40.0);
        float glow = exp(-d * d / 6.0) * 0.9 + exp(-d * d / 60.0) * 0.25;
        float a = glow * twinkle * ubuf.strength;
        col = mix(col, ubuf.mote.rgb, clamp(a / max(alpha + a, 1e-4), 0.0, 1.0));
        alpha += a * 0.8;
    }

    alpha = clamp(alpha, 0.0, 1.0) * ubuf.qt_Opacity;
    fragColor = vec4(col * alpha, alpha);
}
