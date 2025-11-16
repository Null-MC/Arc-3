public module screen_trace;

import aperture;
import lib.common;

float3 projectToScreenBounds(const in float3 screenPos, const in float3 screenDir) {
    float3 stepDir = sign(screenDir);
    float3 nextDist = stepDir * 0.5 + 0.5;
    nextDist = (nextDist - fract(screenPos)) / screenDir;

    float closestDist = minOf(nextDist);
    return fma(screenDir, closestDist, screenPos);
}

float3 projectToScreenBounds(const in float3 screenPos, const in float3 screenDir, float maxLen) {
    float3 stepDir = sign(screenDir);
    float3 nextDist = stepDir * 0.5 + 0.5;
    nextDist = (nextDist - fract(screenPos)) / screenDir;

    float closestDist = min(minOf(nextDist), maxLen);
    return fma(screenDir, closestDist, screenPos);
}

float3 projectScreenTrace(const in float3 viewPos, const in float3 screenPos, const in float3 viewDir) {
    float viewDist = length(viewPos);
    float3 viewDir = viewPos / viewDist;

    float3 reflect_viewPos = 0.1 * viewDist * viewDir + viewPos;
    float3 reflect_clipPos = project(ap.camera.projection, reflect_viewPos);
    float3 reflect_screenPos = reflect_clipPos * 0.5 + 0.5;

    float3 screenDir = normalize(reflect_screenPos - screenPos);

    return projectToScreenBounds(screenPos, screenDir);
}
