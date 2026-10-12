#version 440

// The shell's one surface: the screen frame plus every open drawer, drawn as
// a single signed-distance shape. The frame is the screen minus a rounded
// "hole" (the desktop); each drawer is a rounded rect joined to the frame with
// exact concave quarter-circle fillets (Noctalia's concave corners), so it
// reads as growing out of the border.
//
// The goo deforms each drawer by a small symmetric matrix (see Drawer.qml).
//
// Rebuild after editing:  /usr/lib/qt6/bin/qsb --qt6 -o frame.frag.qsb frame.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;          // item size in px
    vec4 inset;         // hole insets: left, top, right, bottom
    float holeRadius;
    float panelRadius;
    float smoothing;    // concave fillet radius where drawers join the frame (0 = hard)
    vec4 color;
    vec4 p0;            // drawers: x, y, w, h (w or h 0 = closed)
    vec4 p1;
    vec4 p2;
    vec4 p3;
    vec4 p4;
    vec4 p5;
    vec4 p6;
    vec4 p7;
    vec4 p8;
    vec4 p9;
    vec4 d0;            // each drawer's goo: m00, m01, m11 (symmetric 2x2)
    vec4 d1;
    vec4 d2;
    vec4 d3;
    vec4 d4;
    vec4 d5;
    vec4 d6;
    vec4 d7;
    vec4 d8;
    vec4 d9;
    vec4 accent;        // the gilded edge's colour
    float ink;          // ink-wash and grain strength (0 = flat)
    float gild;         // gilded edge strength (0 = none)
    float fibre;        // paper fibre strength (0 = none): frosted paper
} ubuf;

float sdRoundBox(vec2 p, vec2 centre, vec2 half_, float r) {
    r = min(r, min(half_.x, half_.y));
    vec2 q = abs(p - centre) - half_ + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// Union with an exact circular fillet of radius r where two shapes meet:
// the crisp concave corner Noctalia draws where a panel joins a bar
// (concave_edge_corners), instead of a soft smooth-min bulge.
float roundUnion(float a, float b, float r) {
    if (r <= 0.0)
        return min(a, b);
    vec2 u = max(vec2(r - a, r - b), vec2(0.0));
    return max(r, min(a, b)) - length(u);
}

// A drawer, deformed by its goo matrix `m` about its centre: the distance is
// measured in the undeformed space (p mapped through the inverse matrix).
float drawer(vec2 p, vec4 r, vec4 m) {
    if (r.z < 0.5 || r.w < 0.5)
        return 1e5;
    vec2 c = r.xy + r.zw * 0.5;
    float det = m.x * m.z - m.y * m.y;
    vec2 q = p - c;
    if (abs(det) > 1e-4)
        q = vec2(m.z * q.x - m.y * q.y, -m.y * q.x + m.x * q.y) / det;
    return sdRoundBox(c + q, c, r.zw * 0.5, ubuf.panelRadius);
}

// Value noise and a few octaves of it: the ink wash. Static (no time), so the
// frame never repaints just for its texture.
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

    vec2 lo = ubuf.inset.xy;
    vec2 hi = ubuf.size - ubuf.inset.zw;
    float d = -sdRoundBox(p, (lo + hi) * 0.5, max((hi - lo) * 0.5, vec2(0.0)), ubuf.holeRadius);

    float k = ubuf.smoothing;
    d = roundUnion(d, drawer(p, ubuf.p0, ubuf.d0), k);
    d = roundUnion(d, drawer(p, ubuf.p1, ubuf.d1), k);
    d = roundUnion(d, drawer(p, ubuf.p2, ubuf.d2), k);
    d = roundUnion(d, drawer(p, ubuf.p3, ubuf.d3), k);
    d = roundUnion(d, drawer(p, ubuf.p4, ubuf.d4), k);
    d = roundUnion(d, drawer(p, ubuf.p5, ubuf.d5), k);
    d = roundUnion(d, drawer(p, ubuf.p6, ubuf.d6), k);
    d = roundUnion(d, drawer(p, ubuf.p7, ubuf.d7), k);
    d = roundUnion(d, drawer(p, ubuf.p8, ubuf.d8), k);
    d = roundUnion(d, drawer(p, ubuf.p9, ubuf.d9), k);

    float a = clamp(0.5 - d, 0.0, 1.0) * ubuf.color.a * ubuf.qt_Opacity;

    // Ink wash: soft, large blooms of slightly lighter and darker ink, and a
    // fine paper grain over them.
    vec3 col = ubuf.color.rgb;
    if (ubuf.ink > 0.0) {
        float wash = fbm(p / 260.0) - 0.5;
        float grain = hash(floor(p)) - 0.5;
        col *= 1.0 + ubuf.ink * (wash * 0.35 + grain * 0.06);
    }

    // Paper: fibres catch a little more light and are a little denser than
    // the sheet between them. Scaled by the paper alone they vanish on dark
    // ink, so a lift that grows as the paper darkens keeps them as visible
    // in dark mode as in light.
    if (ubuf.fibre > 0.0 && a > 0.0) {
        float f = fibres(p);
        float lift = ubuf.fibre * (f * 0.10 - 0.02);
        float luma = dot(col, vec3(0.299, 0.587, 0.114));
        col = col * (1.0 + lift) + vec3(lift * 0.75 * (1.0 - luma));
        a = min(1.0, a * (1.0 + ubuf.fibre * f * 0.10));
    }

    // The gilded edge: a fine line of the accent tracing the shape's boundary
    // just outside it, on the desktop side, so it never takes a pixel from the
    // bar or a drawer (their margins stay exact).
    float lineA = 0.0;
    if (ubuf.gild > 0.0)
        lineA = (1.0 - smoothstep(0.0, 0.9, abs(d - 0.6))) * ubuf.gild * ubuf.qt_Opacity;

    vec3 premul = col * a + ubuf.accent.rgb * lineA * (1.0 - a);
    float outA = a + lineA * (1.0 - a);
    fragColor = vec4(premul, outA);
}
