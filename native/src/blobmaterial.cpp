// Adapted from Ryoku (ryoku/shell/plugin/blobmaterial.cpp, GPL-3.0, github.com/ryoku-dev/ryoku),
// whose blob rendering is itself adapted from Caelestia (GPL-3.0). Changes for
// nafeel/shell are marked "nafeel:".
#include "blobmaterial.hpp"

#include <cstring>

static_assert(sizeof(decltype(BlobRectData::excludeMask)) == sizeof(float),
    "BlobMaterial packs excludeMask into a float slot via memcpy");

QSGMaterialType* BlobMaterial::type() const {
    static QSGMaterialType s_type;
    return &s_type;
}

QSGMaterialShader* BlobMaterial::createShader(QSGRendererInterface::RenderMode) const {
    return new BlobMaterialShader;
}

int BlobMaterial::compare(const QSGMaterial* other) const {
    if (this < other)
        return -1;
    if (this > other)
        return 1;
    return 0;
}

BlobMaterialShader::BlobMaterialShader() {
    setShaderFileName(VertexStage, QStringLiteral(":/shaders/blob.vert.qsb"));
    setShaderFileName(FragmentStage, QStringLiteral(":/shaders/blob.frag.qsb"));
}

bool BlobMaterialShader::updateUniformData(RenderState& state, QSGMaterial* newMaterial, QSGMaterial* oldMaterial) {
    Q_UNUSED(oldMaterial);
    auto* mat = static_cast<BlobMaterial*>(newMaterial);
    QByteArray* buf = state.uniformData();
    Q_ASSERT(buf->size() >= 1488);

    if (state.isMatrixDirty()) {
        const QMatrix4x4 m = state.combinedMatrix();
        memcpy(buf->data(), m.constData(), 64);
    }
    if (state.isOpacityDirty()) {
        const float opacity = state.opacity();
        memcpy(buf->data() + 64, &opacity, 4);
    }

    // Padded rect (offset 68)
    memcpy(buf->data() + 68, &mat->m_paddedX, 4);
    memcpy(buf->data() + 72, &mat->m_paddedY, 4);
    memcpy(buf->data() + 76, &mat->m_paddedW, 4);
    memcpy(buf->data() + 80, &mat->m_paddedH, 4);

    // Smooth factor (offset 84)
    memcpy(buf->data() + 84, &mat->m_smoothFactor, 4);

    // Rect count (offset 88)
    memcpy(buf->data() + 88, &mat->m_rectCount, 4);

    // My index (offset 92)
    memcpy(buf->data() + 92, &mat->m_myIndex, 4);

    // Color as vec4 (offset 96, 16 bytes)
    const float color[4] = {
        static_cast<float>(mat->m_color.redF()),
        static_cast<float>(mat->m_color.greenF()),
        static_cast<float>(mat->m_color.blueF()),
        static_cast<float>(mat->m_color.alphaF()),
    };
    memcpy(buf->data() + 96, color, 16);

    // Has inverted (offset 112)
    memcpy(buf->data() + 112, &mat->m_hasInverted, 4);

    // Inverted radius (offset 116)
    memcpy(buf->data() + 116, &mat->m_invertedRadius, 4);

    // Shadow params at offsets 120, 124 (the vec4-alignment padding slot)
    memcpy(buf->data() + 120, &mat->m_shadowStrength, 4);
    memcpy(buf->data() + 124, &mat->m_shadowSize, 4);

    // Inverted outer (offset 128, 16 bytes)
    memcpy(buf->data() + 128, mat->m_invertedOuter, 16);

    // Inverted inner (offset 144, 16 bytes)
    memcpy(buf->data() + 144, mat->m_invertedInner, 16);

    // Rect data (offset 160, each rect = 5 vec4s = 80 bytes)
    const int count = qMin(mat->m_rectCount, 16);
    for (int i = 0; i < count; ++i) {
        const auto& r = mat->m_rects[i];
        const int base = 160 + i * 80;
        // Pack excludeMask into props.x via bit-cast (read in shader with floatBitsToInt)
        float maskAsFloat;
        memcpy(&maskAsFloat, &r.excludeMask, sizeof(float));
        const float d0[4] = { r.cx, r.cy, r.hw, r.hh };
        const float d1[4] = { maskAsFloat, r.offsetX, r.offsetY, r.minEig };
        const float d3[4] = { r.screenHalfX, r.screenHalfY, r.sinkWeight, r.wet };
        memcpy(buf->data() + base, d0, 16);
        memcpy(buf->data() + base + 16, d1, 16);
        memcpy(buf->data() + base + 32, r.invDeform, 16);
        memcpy(buf->data() + base + 48, d3, 16);
        memcpy(buf->data() + base + 64, r.radius, 16);
    }

    // Border color as vec4 (offset 1440) + width (offset 1456)
    const float border[4] = {
        static_cast<float>(mat->m_borderColor.redF()),
        static_cast<float>(mat->m_borderColor.greenF()),
        static_cast<float>(mat->m_borderColor.blueF()),
        static_cast<float>(mat->m_borderColor.alphaF()),
    };
    memcpy(buf->data() + 1440, border, 16);
    memcpy(buf->data() + 1456, &mat->m_borderWidth, 4);

    // nafeel: the paper (offsets 1460..1488)
    memcpy(buf->data() + 1460, &mat->m_ink, 4);
    memcpy(buf->data() + 1464, &mat->m_fibre, 4);
    memcpy(buf->data() + 1468, &mat->m_gild, 4);
    const float accent[4] = {
        static_cast<float>(mat->m_accent.redF()),
        static_cast<float>(mat->m_accent.greenF()),
        static_cast<float>(mat->m_accent.blueF()),
        static_cast<float>(mat->m_accent.alphaF()),
    };
    memcpy(buf->data() + 1472, accent, 16);

    return true;
}
