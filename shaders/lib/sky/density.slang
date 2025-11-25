public module density;

import aperture;
import lib.common;


extern static const bool Sky_FogNoise;

Sampler3D<half> texFogNoise;


float GetWorldFogDensity() {
    float density;
    switch (DIMENSION) {
        case DIM_END:
            density = 0.010;
            break;
        case DIM_NETHER:
            density = 0.020;
            break;
        default:
            float dayF = smoothstep(-0.08, 0.002, scene[0].SunLocalDir.y);
            density = lerp(0.220, 0.009, dayF);
            density = lerp(density, 0.440, ap.world.rainStrength);
            density = 1.0;
            break;
    }
    return density;
}

static const uint3 texFogSize = uint3(256, 32, 256);

float SampleFogNoise_low(const in float3 worldPos) {
    const float3 scale = 0.8 / texFogSize;
    float3 samplePos = worldPos * scale;

    float density = texFogNoise.Sample(samplePos - 0.012*float3(0.7, -0.2, 0.08)*ap.timing.timeElapsed);
    return smoothstep(0.0, 1.0, density);
}

float SampleFogNoise_high(const in float3 worldPos) {
    const float3 scale = 1.0 / texFogSize;
    float3 samplePos = worldPos * scale;

    float density;
    density  = texFogNoise.Sample(samplePos - 0.012*float3(0.12, 0.74, 0.08)*ap.timing.timeElapsed);
    density *= texFogNoise.Sample((samplePos + 0.012*float3(0.25, 0.65, -0.02)*ap.timing.timeElapsed)*2.0);

    return smoothstep(0.32, 0.38, density);
}

float SampleFogDensity(const in float3 localPos) {
    float density = scene[0].WorldFogDensity;

    if (Sky_FogNoise) {
        float3 worldPos = localPos + ap.camera.position;
        density *= SampleFogNoise_low(worldPos) + 0.5;
    }

    float worldPosY = localPos.y + ap.camera.position.y;

    if (World_HasSky) {
        density *= rcp(1.0 + max(worldPosY - settings.Sky_SeaLevel, 0.0));
    }

    // if (Sky_FogNoise) {
    //     // float dayF = 1.0;
    //     float ground_scale = 1.0;
    //     if (World_HasSky) {
    //         // dayF = smoothstep(-0.08, 0.002, scene[0].SunLocalDir.y);
    //         ground_scale = smoothstep(12.0, 0.0, worldPosY - settings.Sky_SeaLevel);
    //     }

    //     density += SampleFogNoise_high(worldPos) * ground_scale;
    // }

    return density;
}
