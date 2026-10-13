#version 440

// An icon in one colour (AppIcon's "tinted"): its grey, lifted a touch, times
// the ink, keeping its shading. MultiEffect's colorization did the same in a
// dozen items and an offscreen copy of the icon per icon; this samples the
// image itself.
//
// Rebuild after editing:  /usr/lib/qt6/bin/qsb --qt6 -o tint.frag.qsb tint.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 ink;           // the colour (opaque)
    float lift;         // brightness added before the grey (0.15)
} ubuf;

layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 c = texture(source, qt_TexCoord0);
    float grey = dot(c.rgb + ubuf.lift * c.a, vec3(0.299, 0.587, 0.114));
    fragColor = vec4(grey * ubuf.ink.rgb, c.a) * ubuf.qt_Opacity;
}
