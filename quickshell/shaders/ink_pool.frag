#version 440

// A pool of ink fading out to nothing (the polkit prompt's ground under the
// lock's formation): darkest in the middle, a long soft falloff, its rim
// stirred a little so it reads as ink rather than a vignette.
//
// Rebuild after editing:  /usr/lib/qt6/bin/qsb --qt6 -o ink_pool.frag.qsb ink_pool.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 inkColor;
    float strength;
} ubuf;

void main() {
    vec2 p = qt_TexCoord0 * 2.0 - 1.0;
    float a = atan(p.y, p.x);
    float r = length(p) * (1.0 + 0.035 * sin(a * 5.0) + 0.02 * sin(a * 11.0 + 1.3));
    float k = 1.0 - smoothstep(0.0, 1.0, r);
    float alpha = ubuf.strength * k * k * (3.0 - 2.0 * k);
    fragColor = vec4(ubuf.inkColor.rgb, 1.0) * alpha * ubuf.qt_Opacity;
}
