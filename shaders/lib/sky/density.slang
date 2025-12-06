public module density;

import aperture;
import lib.common;
import lib.sky.common;
import lib.sky.scattering;
import lib.light.floodfill_sky;

extern static const float Fog_DensityIndoors = 4.0;
extern static const bool Sky_FogNoise;

Sampler3D<half> texFogNoise;


float GetWorldFogDensity(const in float rainStrength) {
    float density;
    switch (DIMENSION) {
        case DIM_END:
            density = 0.010;
            break;
        case DIM_NETHER:
            density = 0.020;
            break;
        default:
            float dayF = smoothstep(-0.08, 0.12, scene[0].SunLocalDir.y);
            density = lerp(2.4, 0.2, dayF);
            density = lerp(density, 6.0, rainStrength);
            // density = lerp(density, 1.0, ap.world.thunderStrength);
            break;
    }
    return density;
}

static const uint3 texFogSize = uint3(256, 32, 256);

float SampleFogNoise_low(const in float3 worldPos) {
    const float3 scale = 2.0 / texFogSize;
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
    // float3 skyPos = getSkyPosition(localPos);
    // float altitudeKM = getSkyAltitude(skyPos);
    // float density = getMieDensity(altitudeKM);// * 0.01;

    // float density = GetWorldFogDensity();
    float density = scene[0].WorldFogDensity;
    float3 worldPos = localPos + ap.camera.position;

    if (Sky_FogNoise) {
        density *= SampleFogNoise_low(worldPos) + 0.5;
    }

    float worldPosY = localPos.y + ap.camera.position.y;

    if (World_HasSky) {
        density *= rcp(1.0 + 0.1*max(worldPosY - settings.Sky_SeaLevel, 0.0));

        // float groundFogDensity = smoothstep(0.002, -0.08, scene[0].SunLocalDir.y);
        // groundFogDensity = lerp(groundFogDensity, 1.0, ap.world.rainStrength);

        // float ground_scale = smoothstep(8.0, 0.0, worldPosY - settings.Sky_SeaLevel);
        // if (Sky_FogNoise) ground_scale *= SampleFogNoise_high(worldPos);
        // density += 2.0 * ground_scale * groundFogDensity;
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

    if (World_HasSky) {
        float3 skyBufferPos = FloodFill_Sky_GetBufferPosition(localPos);
        if (FloodFill_Sky_InBounds(skyBufferPos)) {
            float skyLightF = floodfill_sky_sample(skyBufferPos);
            float indoorF = smoothstep(0.0, 0.5, skyLightF);

            density = lerp(Fog_DensityIndoors, density, indoorF);
        }
    }

    return density;
}
