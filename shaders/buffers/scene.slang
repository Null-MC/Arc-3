public module scene_buffer;

import buffers.sky;

extern static const int Shadow_CascadeCount;

struct SceneBuffer {
    float2 taa_jitter;
    float2 taa_jitter_prev;
    float exposure;

    half3 SunColor;
    float3 SunLocalDir;
    half3 MoonColor;
    float3 MoonLocalDir;
    float3 SkyLightLocalDir;

    float3 FloodFillCenter;

    float2 shadowViewMin[Shadow_CascadeCount]; // 2*4
    float2 shadowViewMax[Shadow_CascadeCount]; // 2*4

    float2 WeatherOffset;
    SkyParameters sky;

    // float4x4 viewProjection;
    float4x4 viewProjectionInv;
};
