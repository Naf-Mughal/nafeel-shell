#version 440

// A card of the frame's paper (components/PaperSheet): its colour with the
// same ink wash and paper fibre as the frame and the panels, inside a
// rounded box. Static.
//
// Rebuild after editing:  /usr/lib/qt6/bin/qsb --qt6 -o paper_sheet.frag.qsb paper_sheet.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    float radius;
    vec4 color;
    float ink;
    float fibre;
} ubuf;

float sdRoundBox(vec2 p, vec2 centre, vec2 half_, float r) {
    r = min(r, min(half_.x, half_.y));
    vec2 q = abs(p - centre) - half_ + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

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
        p = p * 2.03 + 11.7;
        a *= 0.5;
    }
    return v;
}

// Paper fibre: thin strands at a few angles (noise stretched along each) and
// a sparse speckle, like rice paper held up to light. Static.
float fibres(vec2 p) {
    float f = 0.0;
    for (int i = 0; i < 3; i++) {
        float ang = 0.55 + float(i) * 2.09;
        vec2 q = mat2(cos(ang), -sin(ang), sin(ang), cos(ang)) * p;
        float n = noise(vec2(q.x / 46.0, q.y / 1.7) + float(i) * 17.3);
        f += smoothstep(0.74, 0.96, n);
    }
    float speck = step(0.996, hash(floor(p / 2.0)));
    return clamp(f / 2.0 + speck * 0.6, 0.0, 1.0);
}

void main() {
    vec2 p = qt_TexCoord0 * ubuf.size;
    float d = sdRoundBox(p, ubuf.size * 0.5, ubuf.size * 0.5, ubuf.radius);
    float a = clamp(0.5 - d, 0.0, 1.0) * ubuf.color.a * ubuf.qt_Opacity;
    if (a <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }
    vec3 col = ubuf.color.rgb;
    if (ubuf.ink > 0.0) {
        float wash = fbm(p / 260.0) - 0.5;
        float grain = hash(floor(p)) - 0.5;
        col *= 1.0 + ubuf.ink * (wash * 0.35 + grain * 0.06);
    }
    if (ubuf.fibre > 0.0) {
        float f = fibres(p);
        float lift = ubuf.fibre * (f * 0.10 - 0.02);
        float luma = dot(col, vec3(0.299, 0.587, 0.114));
        col = col * (1.0 + lift) + vec3(lift * 0.75 * (1.0 - luma));
        a = min(1.0, a * (1.0 + ubuf.fibre * f * 0.10));
    }
    fragColor = vec4(col * a, a);
}
