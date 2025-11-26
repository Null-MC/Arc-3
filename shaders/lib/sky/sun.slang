public module sun;

import lib.common;

static const float sunSolidAngle = 0.0068;
// static const float sunSolidAngle = solidAngle(sun_distanceMm, sun_radiusMm);
static const float sun_distanceMm = 149600.0 * 0.5;
static const float sun_radiusMm = 695.7;


// float skyDisc(const in float3 rayDir, const in float3 lightDir, const in float solidAngle) {
//     float minCosTheta = cos(solidAngle);
//     float cosTheta = dot(rayDir, lightDir);
//     return step(minCosTheta, cosTheta);
// }

float solidAngle(float dist, float rad) {
    return (2.0 * PI) * (1.0 - rad / (rad*rad + dist*dist));
    // return PI * pow2(rad / dist);
}

float skySphere(const in float3 rayDir, const in float3 lightDir, const in float solidAngle) {
    float minCosTheta = cos(solidAngle);
    float cosTheta = dot(rayDir, lightDir);
    return saturate((cosTheta - minCosTheta) / (1.0 - minCosTheta));
}

float sun(float3 rayDir, float3 sunDir) {
    // const float minCosTheta = cos(sunSolidAngle);
    return skySphere(rayDir, sunDir, sunSolidAngle);
}
