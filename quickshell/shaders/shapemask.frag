#version 440

// A picture cut to a shape (ShapeImage): the picture times the shape's
// coverage, its antialiased edge kept. Samples the image itself (MultiEffect's
// mask made an offscreen copy and a dozen items per picture).
//
// Rebuild after editing:  /usr/lib/qt6/bin/qsb --qt6 -o shapemask.frag.qsb shapemask.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
} ubuf;

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D mask;

void main() {
    fragColor = texture(source, qt_TexCoord0) * texture(mask, qt_TexCoord0).a * ubuf.qt_Opacity;
}
