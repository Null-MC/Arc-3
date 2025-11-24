public module density;

import aperture;
import lib.common;


extern static const bool FOG_NOISE_ENABLED = false;

Sampler3D<half> texFogNoise;


float SampleFogNoise(const in float3 localPos) {
    const float3 scale = 0.5 / float3(256, 32, 256);

    float3 worldPos = localPos + ap.camera.position;
    float3 samplePos = worldPos * scale;

    float density = texFogNoise.Sample(samplePos);
    return 100.0 * smoothstep(0.62, 0.68, density);
    // return 100.0 * step(0.62, density) * vertical_scale;
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

    if (FOG_NOISE_ENABLED) {
        density += SampleFogNoise(localPos);
    }

    float worldPosY = localPos.y + ap.camera.position.y;
    float vertical_scale = 1.0 - saturate(unmix(60.0, 90.0, worldPosY));
    density *= vertical_scale;

    return density;
}
