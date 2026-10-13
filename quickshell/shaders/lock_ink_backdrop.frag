#version 440

// Moonlit ink-wash backdrop for the "Sealed Cave Abode" lock theme.
//
// The wallpaper is softened and remapped from its luminance onto an ink
// palette (dark hollows stay ink, light areas become pale mist), then drifting
// mist, rice-paper grain and slowly rising golden qi motes are layered on
// top. Everything that moves is a function of `time`, which only advances
// while the lock screen is awake.
//
// Cheap per pixel: the wallpaper comes at half resolution (the downscale is
// the softening: one tap, not nine) and the mist banks from their own quarter
// resolution pass (lock_ink_mist), so a frame fits well inside 60 fps.
//
// Rebuild after editing:  /usr/lib/qt6/bin/qsb --qt6 -o lock_ink_backdrop.frag.qsb lock_ink_backdrop.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float time;
    float motes;       // 0..1 qi mote intensity
    vec4 inkColor;     // opaque
    vec4 mistColor;    // opaque
    vec4 goldColor;    // opaque
} ubuf;

layout(binding = 1) uniform sampler2D wall;
layout(binding = 2) uniform sampler2D mist;  // r: mist bank * depth

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 uv = qt_TexCoord0;

    // The wallpaper, already softened by its half-resolution capture.
    vec3 w = texture(wall, uv).rgb;
    float l = dot(w, vec3(0.299, 0.587, 0.114));

    // Ink remap: hollows stay ink, highlights turn to moonlit mist.
    float tone = pow(smoothstep(0.04, 0.95, l), 1.25);
    vec3 col = mix(ubuf.inkColor.rgb, ubuf.mistColor.rgb, tone * 0.6);

    // Drifting mist banks, thicker towards the valleys at the bottom (their
    // own small pass).
    float t = ubuf.time;
    col = mix(col, ubuf.mistColor.rgb * 1.05, texture(mist, uv).r);

    // Rice-paper grain, barely there (stronger reads as noise).
    col += (hash(floor(uv * res)) - 0.5) * 0.008;

    // Golden qi motes rising in two parallax layers.
    float aspect = res.x / res.y;
    for (int k = 0; k < 2; k++) {
        float fk = float(k);
        vec2 grid = vec2(14.0, 8.0) * (1.0 + fk * 0.7);
        vec2 p = vec2(uv.x * aspect, uv.y) * grid.y + vec2(0.0, t * (0.35 + fk * 0.25));
        vec2 cell = floor(p);
        float h = hash(cell + fk * 31.0);
        if (h > 0.62) {
            vec2 f = fract(p) - 0.5 - (vec2(hash(cell + 7.0), hash(cell + 13.0)) - 0.5) * 0.6;
            f.x += 0.12 * sin(t * 0.8 + h * 20.0);
            float d = length(f);
            float twinkle = 0.55 + 0.45 * sin(t * 2.2 + h * 40.0);
            float glow = smoothstep(0.09 - fk * 0.03, 0.0, d) * twinkle;
            col += ubuf.goldColor.rgb * glow * ubuf.motes * (0.55 - fk * 0.2);
        }
    }

    // Vignette.
    vec2 c = uv - 0.5;
    c.x *= aspect;
    col *= mix(1.0, 0.45, smoothstep(0.35, 1.15, length(c)));

    fragColor = vec4(col, 1.0) * ubuf.qt_Opacity;
}
