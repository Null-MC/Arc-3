public module DDA;

import lib.common;

void DDA_init(out float3 stepSizes, out float3 nextDist, const in float3 currPos, const in float3 localDir) {
    float3 stepDir = sign(localDir);
    stepSizes = rcp(abs(localDir));

    nextDist = stepDir * 0.5 + 0.5;
    nextDist = (nextDist - fract(currPos)) / localDir;
}

float3 DDA_step(out float3 stepAxis, inout float3 nextDist, const in float3 stepSizes, const in float3 localDir) {
    float closestDist = minOf(nextDist);
    stepAxis = float3(nextDist <= closestDist);

    nextDist -= closestDist;
    nextDist = fma(stepSizes, stepAxis, nextDist);

    return localDir * closestDist;
}

float3 projectToScreenBounds(const in float3 screenPos, const in float3 screenDir) {
    float3 stepDir = sign(screenDir);
    float3 nextDist = stepDir * 0.5 + 0.5;
    nextDist = (nextDist - fract(screenPos)) / screenDir;

    float closestDist = minOf(nextDist);
    return fma(screenDir, closestDist, screenPos);
}
