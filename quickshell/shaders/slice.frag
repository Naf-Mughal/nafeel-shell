#version 440

// One slice of the wallpaper carousel (after Ryoku's SliceDelegate, MIT): the
// picture cut as a slanted card (a parallelogram leaning `skew` px, rounded
// corners), dimmed when it isn't the chosen one, with a rim (ink for the
// selection, gold for the current wallpaper) and a soft shadow below it.
//
// Rebuild after editing:  /usr/lib/qt6/bin/qsb --qt6 -o slice.frag.qsb slice.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;      // the slice's box in px (the shadow's margin included)
    float pad;      // px of that margin around the card (for the shadow)
    float skew;     // px the top edge sits right of the bottom one
    float radius;
    float dim;      // 0 = as is, 1 = black
    vec4 rim;       // rim colour (alpha = 0: none)
    float rimWidth;
    float shadow;   // shadow strength
} ubuf;

layout(binding = 1) uniform sampler2D source;

// A rounded box's signed distance (centre-relative point, half size).
float box(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float slice(vec2 px) {
    vec2 card = ubuf.size - 2.0 * ubuf.pad;
    vec2 p = px - ubuf.pad;
    // Shear so the slanted sides stand upright: the top moves left by skew.
    float t = 1.0 - p.y / card.y;
    p.x -= ubuf.skew * t;
    vec2 half_ = vec2((card.x - ubuf.skew) * 0.5, card.y * 0.5);
    return box(p - half_, half_, min(ubuf.radius, min(half_.x, half_.y)));
}

void main() {
    vec2 px = qt_TexCoord0 * ubuf.size;
    float d = slice(px);
    float aa = 1.0;
    float inside = 1.0 - smoothstep(-aa, 0.0, d);

    // The picture spans the card box (the shadow margin cropped off).
    vec2 uv = (px - ubuf.pad) / (ubuf.size - 2.0 * ubuf.pad);
    vec4 img = texture(source, clamp(uv, 0.0, 1.0));
    img.rgb *= 1.0 - ubuf.dim;

    // Rim just inside the edge.
    float rim = (1.0 - smoothstep(-aa, 0.0, d)) * smoothstep(-ubuf.rimWidth - aa, -ubuf.rimWidth, d);
    img.rgb = mix(img.rgb, ubuf.rim.rgb, rim * ubuf.rim.a);

    vec4 col = vec4(img.rgb, 1.0) * inside;

    // A soft shadow below and to the right, outside the card.
    float ds = slice(px - vec2(3.0, 8.0));
    float sh = (1.0 - smoothstep(-6.0, 14.0, ds)) * ubuf.shadow * (1.0 - inside);
    col += vec4(0.0, 0.0, 0.0, sh);

    fragColor = col * ubuf.qt_Opacity;
}
