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

float3 projectScreenTrace(const in float3 viewPos, const in float3 screenPos, const in float3 viewDir) {
    float viewDist = length(viewPos);

    float3 dest_viewPos = 0.1 * viewDist * viewDir + viewPos;
    float3 dest_clipPos = project(ap.camera.projection, dest_viewPos);
    float3 dest_screenPos = dest_clipPos * 0.5 + 0.5;

    float3 screenDir = normalize(dest_screenPos - screenPos);

    return projectToScreenBounds(screenPos, screenDir);
}
