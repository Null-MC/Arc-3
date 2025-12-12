public module scene_buffer;

import buffers.sky;

extern static const int Shadow_CascadeCount;

struct SceneBuffer {
    float2 taa_jitter;
    float2 taa_jitter_prev;
    float exposure;

    float3 SunColor;
    float3 SunLocalDir;
    float3 MoonColor;
    float3 MoonLocalDir;
    float3 SkyLightLocalDir;

    float3 WaterScatterColor;
    float3 WaterAbsorbColor;
    float WorldFogDensity;

    float3 FloodFillCenter;

    float2 shadowViewMin[Shadow_CascadeCount]; // 2*4 =8
    float2 shadowViewMax[Shadow_CascadeCount]; // 2*4 =8

    float2 WeatherOffset;
    float WetnessGround;
    SkyParameters sky;              // 9

    float4x4 viewProjectionInv;     // 16
    float4x4 viewProjectionLast;    // 16
};
