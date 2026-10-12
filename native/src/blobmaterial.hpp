// Adapted from Ryoku (ryoku/shell/plugin/blobmaterial.hpp, GPL-3.0, github.com/ryoku-dev/ryoku),
// whose blob rendering is itself adapted from Caelestia (GPL-3.0). Changes for
// nafeel/shell are marked "nafeel:".
#pragma once

#include <qcolor.h>
#include <qsgmaterial.h>
#include <qsgmaterialshader.h>

struct BlobRectData {
    float cx = 0, cy = 0, hw = 0, hh = 0;
    float offsetX = 0, offsetY = 0;
    float minEig = 1.0f;
    // Inverse of 2x2 deformation matrix, column-major for GLSL
    float invDeform[4] = { 1, 0, 0, 1 };
    // Screen-space AABB half-extents of the deformed rect
    float screenHalfX = 0, screenHalfY = 0;
    // 0 = this rect never pockets the inverted border (border sinks off)
    float sinkWeight = 1.0f;
    // nafeel: how wet the ink is (0..1): ragged edges and a fatter join
    float wet = 0.0f;
    // Effective per-corner radii (tr, br, bl, tl), pre-computed on CPU
    float radius[4] = { 0, 0, 0, 0 };
    // Bitmask of indices in this rect's m_cachedRects that mutually exclude (or are excluded by) this rect.
    // Used by the shader to skip smin between excluded pairs.
    int excludeMask = 0;
};

class BlobMaterial : public QSGMaterial {
public:
    QSGMaterialType* type() const override;
    QSGMaterialShader* createShader(QSGRendererInterface::RenderMode) const override;
    int compare(const QSGMaterial* other) const override;

    float m_paddedX = 0;
    float m_paddedY = 0;
    float m_paddedW = 0;
    float m_paddedH = 0;
    float m_smoothFactor = 32.0f;
    int m_rectCount = 0;
    int m_myIndex = -2;
    QColor m_color{ 0x44, 0x88, 0xff };
    QColor m_borderColor{ 0, 0, 0, 0 };
    float m_borderWidth = 0.0f;
    // nafeel: the paper
    float m_ink = 0.0f;
    float m_fibre = 0.0f;
    float m_gild = 0.0f;
    QColor m_accent{ 0, 0, 0, 0 };
    int m_hasInverted = 0;
    float m_invertedRadius = 0;
    float m_shadowStrength = 0;
    float m_shadowSize = 0;
    float m_invertedOuter[4] = {};
    float m_invertedInner[4] = {};
    BlobRectData m_rects[16] = {};
};

class BlobMaterialShader : public QSGMaterialShader {
public:
    BlobMaterialShader();
    bool updateUniformData(RenderState& state, QSGMaterial* newMaterial, QSGMaterial* oldMaterial) override;
};
