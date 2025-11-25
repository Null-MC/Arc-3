public module density;

import aperture;
import lib.common;


extern static const bool Sky_FogNoise;

Sampler3D<half> texFogNoise;


float SampleFogNoise(const in float3 localPos) {
    const float3 scale = 1.0 / float3(256, 32, 256);

    float3 worldPos = localPos + ap.camera.position;
    float3 samplePos = worldPos * scale;

    float density;
    density  = texFogNoise.Sample(samplePos + 0.012*float3(0.12, 0.74, 0.08)*ap.timing.timeElapsed);
    density *= texFogNoise.Sample((samplePos + 0.012*float3(0.25, 0.65, 0.02)*ap.timing.timeElapsed)*2.0);

    return smoothstep(0.32, 0.38, density);
}

float SampleFogDensity(const in float3 localPos) {
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
            density = lerp(0.034, 0.009, dayF);
            density = lerp(density, 0.07, ap.world.rainStrength);
            break;
    }

    if (Sky_FogNoise) {
        density += SampleFogNoise(localPos);
    }

    float worldPosY = localPos.y + ap.camera.position.y;
    float vertical_scale = rcp(1.0 + max(worldPosY - settings.Sky_SeaLevel, 0.0));
    density *= vertical_scale;

    return density;
}
