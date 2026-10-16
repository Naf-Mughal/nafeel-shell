#version 440

// The session's entrance (plugins/lock/Entrance.qml): the login screen's
// surface, drawn into a layer, recedes into the desktop under it along the
// same organic front as lock_ink_dissolve's outro. That shader re-forms a
// screenshot over the ink; at login there's no desktop to grab yet, so here
// the ink itself is cut away instead and the real desktop shows through.
// Run back from 1 to 0 (`progress`, the surface's `dissolve`), with
// `inward`: the desktop opens from the centre out. Same front, same gold rim.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float progress;
    float inward;
    vec2 origin;
    vec4 goldColor;  // opaque
} ubuf;

layout(binding = 1) uniform sampler2D source;

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
        p = p * 2.07 + vec2(11.7, 3.9);
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 col = texture(source, uv);

    if (ubuf.progress >= 1.0) {
        fragColor = col * ubuf.qt_Opacity;
        return;
    }

    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 aspect = vec2(res.x / res.y, 1.0);
    vec2 o = ubuf.origin;
    float reach = length(max(o, 1.0 - o) * aspect);
    float d = length((uv - o) * aspect) / max(reach, 0.001);
    if (ubuf.inward > 0.5)
        d = 1.0 - d;
    float n = fbm(uv * aspect * 3.5);
    float v = clamp(d * 0.62 + n * 0.38, 0.0, 1.0);

    const float w = 0.1;
    float t = ubuf.progress * (1.0 + w) - w;
    // Behind the front: still ink.
    if (v < t) {
        fragColor = col * ubuf.qt_Opacity;
        return;
    }
    // Ahead of it: the desktop. At the front the ink thins out, with the rim.
    float k = (v - t) / w;
    if (k >= 1.0) {
        fragColor = vec4(0.0);
        return;
    }
    float keep = 1.0 - smoothstep(0.0, 1.0, k);
    float rim = 1.0 - smoothstep(0.0, 0.18, k);
    vec4 gold = vec4(ubuf.goldColor.rgb, 1.0);
    fragColor = mix(col * keep, gold, rim * 0.9) * ubuf.qt_Opacity;
}
