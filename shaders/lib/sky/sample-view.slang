public module sample_view;

import lib.common;
import lib.sky.common;

Sampler2D<half3> texSkyView;

half3 sampleSkyView(const in float3 skyPos, const in float3 rayDir, const in float3 sunDir) {
    float height = length(skyPos);
    float3 up = skyPos / height;

    float elevation2 = max(height * height - groundRadiusMM * groundRadiusMM, 0.0);
    float horizonAngle = safeacos(sqrt(elevation2) / height);
    float altitudeAngle = horizonAngle - acos(dot(rayDir, up)); // Between -PI/2 and PI/2
    float azimuthAngle; // Between 0 and 2*PI
    if (abs(altitudeAngle) > (0.5*PI - 0.0001)) {
        // Looking nearly straight up or down.
        azimuthAngle = 0.0;
    } else {
        float3 right = cross(sunDir, up);
        float3 forward = cross(up, right);
        
        float3 projectedDir = normalize(rayDir - up*(dot(rayDir, up)));
        float sinTheta = dot(projectedDir, right);
        float cosTheta = dot(projectedDir, forward);
        azimuthAngle = atan2(sinTheta, cosTheta) + PI;
    }
    
    // Non-linear mapping of altitude angle. See Section 5.3 of the paper.
    float v = 0.5 + 0.5*sign(altitudeAngle) * sqrt(abs(altitudeAngle) * 2.0/PI);
    float2 uv = float2(azimuthAngle / (2.0*PI), v);
    
    uv.y = clamp(uv.y, (0.5/skyViewDimensions.y), ((skyViewDimensions.y-1.0)/skyViewDimensions.y));

    return texSkyView.SampleLevel(uv, 0);
}
