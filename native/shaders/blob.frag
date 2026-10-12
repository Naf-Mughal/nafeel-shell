#version 440
// Adapted from Ryoku (ryoku/shell/plugin/shaders, GPL-3.0); nafeel: changes marked.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float paddedX;
    float paddedY;
    float paddedW;
    float paddedH;
    float smoothFactor;
    int rectCount;
    int myIndex;
    vec4 color;
    int hasInverted;
    float invertedRadius;
    float shadowStrength;
    float shadowSize;
    vec4 invertedOuter;
    vec4 invertedInner;
    vec4 rectData[80];
    vec4 borderColor;
    float borderWidth;
    // nafeel: the paper
    float ink;
    float fibre;
    float gild;
    vec4 accent;
};

// nafeel: the paper's texture, in screen space (so every renderer of a merged
// blob paints the same pixel the same way). Static: no time.
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

float sdRoundedBox(vec2 p, vec2 center, vec2 halfSize, float radius) {
    vec2 d = abs(p - center) - halfSize + vec2(radius);
    return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - radius;
}

float sdRoundedBox4(vec2 p, vec2 center, vec2 halfSize, vec4 r) {
    // r = (topRight, bottomRight, bottomLeft, topLeft)
    p -= center;
    r.xy = (p.x > 0.0) ? r.xy : r.wz;
    r.x  = (p.y > 0.0) ? r.y : r.x;
    vec2 q = abs(p) - halfSize + r.x;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r.x;
}

float sdBox(vec2 p, vec2 center, vec2 halfSize) {
    vec2 d = abs(p - center) - halfSize;
    return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
}

float smin(float a, float b, float k) {
    // Circular smooth min — the blend fillet is a true circular arc of radius k,
    // tangent to both surfaces (not a polynomial/squircle curve). Deviates from
    // min(a, b) only in the corner region where BOTH a < k and b < k (unlike the
    // cubic it replaced, which deviated over the whole band |a - b| < k). Always
    // <= min(a, b); max blend depth at a == b is (sqrt(2) - 1) * k. It is C1 but
    // not C2 at the support boundary, so a circular-arc fillet shows the usual
    // line-meets-arc curvature step — by design, that is the "circular" look.
    return max(k, min(a, b)) - length(max(vec2(k) - vec2(a, b), vec2(0.0)));
}

float smax(float a, float b, float k) {
    // Circular smooth max — dual of smin: -smin(-a, -b, k). Always >= max(a, b).
    return min(-k, max(a, b)) + length(max(vec2(a, b) + vec2(k), vec2(0.0)));
}

float smaxSharpA(float a, float b, float k) {
    // Circular smax variant that keeps a's boundary sharp (no inward rounding at
    // a = 0). Used for the frame outer edge so it always fills to the edges.
    float sm = min(-k, max(a, b)) + length(max(vec2(a, b) + vec2(k), vec2(0.0)));
    float blend = (sm - max(a, b)) * smoothstep(0.0, k * 0.5, -a);
    return max(a, b) + blend;
}

void main() {
    vec2 pixel = vec2(paddedX, paddedY) + qt_TexCoord0 * vec2(paddedW, paddedH);

    // Phase 1: compute per-rect SDF, track owner. We can't smin yet because excluded
    // pairs need to skip the smooth blend, which requires pairwise pass below.
    float dArr[16];
    // nafeel: each rect's wetness, and the nearest rect's (for the frame join)
    float wetArr[16];
    float nearestWet = 0.0;
    float nearestD = 1e10;
    int owner = -2;
    float minDist = 1e10;

    for (int i = 0; i < rectCount; i++) {
        vec4 rect = rectData[i * 5];         // cx, cy, hw, hh
        vec4 props = rectData[i * 5 + 1];    // excludeMask(int bits), offsetX, offsetY, minEig
        vec4 invDm = rectData[i * 5 + 2];    // inverse deform matrix
        vec4 sh = rectData[i * 5 + 3];       // screenHalfX, screenHalfY, 0, 0
        vec4 radii = rectData[i * 5 + 4];    // effective per-corner radii (tr, br, bl, tl)

        // Offset center for asymmetric deformation
        vec2 center = rect.xy + props.yz;

        // AABB early-out: skip rects far from this pixel
        vec2 extent = sh.xy + vec2(smoothFactor * 4.5 + 6.0);
        if (abs(pixel.x - center.x) > extent.x || abs(pixel.y - center.y) > extent.y) {
            dArr[i] = 1e10;
            wetArr[i] = 0.0;
            continue;
        }

        // Apply pre-computed inverse deformation to the evaluation point
        mat2 invDeform = mat2(invDm.xy, invDm.zw);
        vec2 transformedPixel = center + invDeform * (pixel - center);

        // Use pre-computed effective per-corner radii
        float d = sdRoundedBox4(transformedPixel, center, rect.zw, radii);

        // Use pre-computed minimum eigenvalue for SDF correction
        d *= max(props.w, 0.01);

        // Scale SDF on the axis facing a nearby border to narrow the smin blend zone
        // in that direction only, without reducing k (which would cause sharp edges).
        if (hasInverted != 0) {
            vec2 screenHalf = sh.xy;

            float distY0 = (center.y + screenHalf.y) - (invertedInner.y - invertedInner.w);
            float distY1 = (invertedInner.y + invertedInner.w) - (center.y - screenHalf.y);
            float distX0 = (center.x + screenHalf.x) - (invertedInner.x - invertedInner.z);
            float distX1 = (invertedInner.x + invertedInner.z) - (center.x - screenHalf.x);

            // 0 = far from border, 1 = at border (max compression)
            float yProx = 1.0 - min(
                smoothstep(0.0, smoothFactor, distY0),
                smoothstep(0.0, smoothFactor, distY1)
            );
            float xProx = 1.0 - min(
                smoothstep(0.0, smoothFactor, distX0),
                smoothstep(0.0, smoothFactor, distX1)
            );

            // Smooth axis weights: gradient-based at corners, face-based inside.
            vec2 q = abs(pixel - center) - screenHalf;
            vec2 qp = max(q, vec2(0.0));
            float cornerLen = length(qp);

            // Gradient direction in corner region (smooth 90-degree rotation)
            float gradX = qp.x / max(cornerLen, 0.001);
            float gradY = qp.y / max(cornerLen, 0.001);

            // Smooth face weights for inside/edge (no hard branch)
            float faceY = smoothstep(-4.0, 4.0, q.y - q.x);
            float faceX = 1.0 - faceY;

            // Blend: gradient in corner region, face-based inside
            float t = smoothstep(0.0, 2.0, cornerLen);
            float xWeight = mix(faceX, gradX, t);
            float yWeight = mix(faceY, gradY, t);

            float boost = 3.0;
            float scale = 1.0 + (xProx * xWeight + yProx * yWeight) * boost;
            d *= scale;
        }

        // nafeel: wet ink bleeds: a ragged edge (noise along the boundary)
        // that dries crisp as the wetness falls.
        float wet = sh.w;
        wetArr[i] = wet;
        if (wet > 0.0)
            d += wet * 1.6 * (noise(pixel / 7.0) + 0.6 * noise(pixel / 2.7 + 9.1) - 0.8);
        if (d < nearestD) {
            nearestD = d;
            nearestWet = wet;
        }

        dArr[i] = d;
        if (d < smoothFactor && d < minDist) {
            minDist = d;
            owner = i;
        }
    }

    // Phase 2: hard-min baseline over all rects.
    float mergedSdf = 1e10;
    for (int i = 0; i < rectCount; i++) {
        mergedSdf = min(mergedSdf, dArr[i]);
    }

    // Phase 3: pair-wise smin contributions, skipping excluded pairs. Pair smin <= min,
    // so taking the min over all non-excluded pair smins gives the smoothly-merged SDF.
    for (int i = 0; i < rectCount; i++) {
        if (dArr[i] >= 1e9)
            continue;
        int excludeMask = floatBitsToInt(rectData[i * 5 + 1].x);
        for (int j = i + 1; j < rectCount; j++) {
            if (dArr[j] >= 1e9)
                continue;
            if ((excludeMask & (1 << j)) != 0)
                continue;
            // nafeel: surface tension: wet shapes join with a fatter neck.
            float kij = smoothFactor * (1.0 + 3.0 * max(wetArr[i], wetArr[j]));
            // Circular smin deviates from min only where BOTH dArr are < k.
            if (max(dArr[i], dArr[j]) >= kij)
                continue;
            mergedSdf = min(mergedSdf, smin(dArr[i], dArr[j], kij));
        }
    }

    float frameDist = 1e10;
    if (hasInverted != 0) {
        float dOuter = sdBox(pixel, invertedOuter.xy, invertedOuter.zw) - 1.0;
        float dInner = sdRoundedBox(pixel, invertedInner.xy, invertedInner.zw, invertedRadius);

        // Border sinks: track the opposite rect edge, clamped to border thickness
        float innerTop = invertedInner.y - invertedInner.w;
        float innerBot = invertedInner.y + invertedInner.w;
        float innerLeft = invertedInner.x - invertedInner.z;
        float innerRight = invertedInner.x + invertedInner.z;
        float outerTop = invertedOuter.y - invertedOuter.w;
        float outerBot = invertedOuter.y + invertedOuter.w;
        float outerLeft = invertedOuter.x - invertedOuter.z;
        float outerRight = invertedOuter.x + invertedOuter.z;

        float sinkValue = 0.0;
        for (int i = 0; i < rectCount; i++) {
            vec4 rect = rectData[i * 5];
            vec4 sinkProps = rectData[i * 5 + 1];
            vec2 sinkSh = rectData[i * 5 + 3].xy;
            // 0 = sinks off for this rect (a melting popout must slide in
            // flush, not dig a pocket that snaps back at zero size)
            float sinkW = rectData[i * 5 + 3].z;
            if (sinkW <= 0.0)
                continue;

            // Screen-space center (with offset) and pre-computed AABB half-extents
            vec2 ctr = rect.xy + sinkProps.yz;

            // Sink onset / residual overlap: how far a rect must penetrate the border before
            // the inner wall recedes to form its pocket. Too low and the wall recedes faster
            // than the junction can stay convex, denting the inner edge inward near the rect's
            // (squared) corners; too high and the rect nestles too deep before the wall yields.
            // Tuned between the old cubic blend depth (k/6, too shallow) and the circular blend
            // depth ((sqrt2-1)k): half the circular smin gap-closing distance, (2-sqrt2)k/2.
            float preOff = smoothFactor * (2.0 - sqrt(2.0)) * 0.5;

            // Top border: track rect's BOTTOM edge, only within border thickness
            float topPen = clamp(innerTop - (ctr.y + sinkSh.y) - preOff, 0.0, innerTop - outerTop);

            // Bottom border: track rect's TOP edge
            float botPen = clamp((ctr.y - sinkSh.y) - innerBot - preOff, 0.0, outerBot - innerBot);

            // Left border: track rect's RIGHT edge
            float leftPen = clamp(innerLeft - (ctr.x + sinkSh.x) - preOff, 0.0, innerLeft - outerLeft);

            // Right border: track rect's LEFT edge
            float rightPen = clamp((ctr.x - sinkSh.x) - innerRight - preOff, 0.0, outerRight - innerRight);

            // Lateral distance from pixel to rect's extent along each edge
            float hLat = max(abs(pixel.x - ctr.x) - sinkSh.x, 0.0);
            float vLat = max(abs(pixel.y - ctr.y) - sinkSh.y, 0.0);

            // Perpendicular proximity: full strength in border, fade inside inner area
            float topZone = 1.0 - smoothstep(innerTop, innerTop + smoothFactor, pixel.y);
            float botZone = smoothstep(innerBot - smoothFactor, innerBot, pixel.y);
            float leftZone = 1.0 - smoothstep(innerLeft, innerLeft + smoothFactor, pixel.x);
            float rightZone = smoothstep(innerRight - smoothFactor, innerRight, pixel.x);

            float s = smoothFactor * 2.0;
            float sink = max(
                max(topPen * smoothstep(s, 0.0, hLat) * topZone,
                    botPen * smoothstep(s, 0.0, hLat) * botZone),
                max(leftPen * smoothstep(s, 0.0, vLat) * leftZone,
                    rightPen * smoothstep(s, 0.0, vLat) * rightZone)
            );
            sinkValue = max(sinkValue, sink);
        }

        dInner -= sinkValue;

        // The circular smax fillet has radius kFrame; when it exceeds the border thickness
        // it can't complete inside the border, so the sharp outer-box term bleeds onto the
        // inner edge and bulges the inner corners (worst when thickness < smoothFactor — the
        // default border is thinner than the blend radius). Clamp kFrame to the thinnest side
        // so the inner edge stays a clean constant-radius arc. Each inner corner is bounded by
        // its thinner adjacent side, so the global min is correct for every corner.
        float minThick = min(min(innerTop - outerTop, outerBot - innerBot),
                             min(innerLeft - outerLeft, outerRight - innerRight));
        float kFrame = clamp(min(smoothFactor, minThick - 1.0), 1.0, smoothFactor);
        float dFrame = smaxSharpA(dOuter, -dInner, kFrame);
        frameDist = dFrame;

        // nafeel: a wet drawer joins the frame with a fatter neck too.
        mergedSdf = smin(mergedSdf, dFrame, smoothFactor * (1.0 + 3.0 * nearestWet));
        if (dFrame < minDist) {
            owner = -1;
        }
    }

    float fw = fwidth(mergedSdf);
    float bodyAlpha = 1.0 - smoothstep(-fw, fw, mergedSdf);

    // Frame contact shadow: a soft falloff inward from the border, by distance
    // from the border itself, so it stays uniform along each edge. The pill and
    // popouts are opaque shapes drawn over it (the frame swelling open, not panels
    // on top), so they neither cast a halo nor cut the shadow off.
    float shadowAlpha = 0.0;
    if (shadowStrength > 0.0 && shadowSize > 0.0 && myIndex == -1 && frameDist > 0.0) {
        float t = clamp(1.0 - frameDist / shadowSize, 0.0, 1.0);
        shadowAlpha = shadowStrength * t * t;
    }

    // Owner gate: a renderer paints its own pixels plus the shared blend zone
    // (mergedSdf <= smoothFactor) to prevent seams; the shadow is added only by
    // the border renderer.
    bool ownPixel = (owner == myIndex) || (mergedSdf <= smoothFactor * 4.0);
    // nafeel: the gilded line, just outside the shape (on the desktop side),
    // so it never takes a pixel from the shape itself.
    float lineA = 0.0;
    if (gild > 0.0 && ownPixel)
        lineA = (1.0 - smoothstep(0.0, 0.9, abs(mergedSdf - 0.6))) * gild;
    if (!ownPixel && shadowAlpha <= 0.0)
        discard;

    float bodyA = ownPixel ? bodyAlpha : 0.0;
    // Body color over the (black) shadow, premultiplied.
    float outA = bodyA + shadowAlpha * (1.0 - bodyA);
    // 1-2px outline in borderColor along the silhouette rim (a band just inside sdf = 0)
    vec3 bodyRgb = (borderWidth > 0.0 && borderColor.a > 0.0)
        ? mix(color.rgb, borderColor.rgb, borderColor.a * smoothstep(-borderWidth - fw, -borderWidth + fw, mergedSdf))
        : color.rgb;
    // nafeel: ink wash (soft blooms) and grain, then paper fibre.
    if (bodyA > 0.0) {
        if (ink > 0.0) {
            float wash = fbm(pixel / 260.0) - 0.5;
            float grain = hash(floor(pixel)) - 0.5;
            bodyRgb *= 1.0 + ink * (wash * 0.35 + grain * 0.06);
        }
        // Paper fibre; the lift grows as the paper darkens, so the strands
        // show on dark ink as they do on light paper.
        if (fibre > 0.0) {
            float lift = fibre * (fibres(pixel) * 0.10 - 0.02);
            float luma = dot(bodyRgb, vec3(0.299, 0.587, 0.114));
            bodyRgb = bodyRgb * (1.0 + lift) + vec3(lift * 0.75 * (1.0 - luma));
        }
    }
    vec3 premul = bodyRgb * bodyA + accent.rgb * lineA * (1.0 - bodyA);
    outA = outA + lineA * (1.0 - outA);
    fragColor = vec4(premul, outA) * qt_Opacity;
}
