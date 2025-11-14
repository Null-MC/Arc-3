public module lmcoord;

import lib.common;

static const float lmCoordMin = ( 0.5/16.0);
static const float lmCoordMax = (15.5/16.0);
// static const float lmCoordRange = lmCoordMax - lmCoordMin;


float2 LightMapNorm(float2 lightCoord) {
    // return (lightCoord - lmCoordMin) / lmCoordRange;
    return unmix(lmCoordMin, lmCoordMax, lightCoord);
}

float2 LightMapTex(float2 lightNorm) {
    // return fma(saturate(lightNorm), float2(lmCoordRange), float2(lmCoordMin));
    return lerp(lmCoordMin, lmCoordMax, saturate(lightNorm));
}
