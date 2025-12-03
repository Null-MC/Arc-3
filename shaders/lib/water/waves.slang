public module waves;

import aperture;
import lib.common;

static const float WaterWaveSurfaceOffset = 0.8;
static const float Scene_WaterWaveHeight = 0.8;

Sampler2D<half> texWaterWaves_high;

// int WaterWaveOctaveMin = int(ceil(settings.Water_WaveDetail * 0.75));
// int WaterWaveOctaveMax = settings.Water_WaveDetail;

// float3 WaterWaveScaleF = float3(1.0, rcp(settings.Water_WaveHeight), 1.0);

// based on: https://www.shadertoy.com/view/MdXyzX

float2 waveDx(const in float2 position, const in float2 direction, const in float frequency, const in float timeshift) {
    float x = dot(direction, position) * frequency + timeshift;
    float xMod = fmod(x, PI * 2.0);

    float wave = exp(sin(xMod) - 1.0);
    float dx = wave * cos(xMod);
    return float2(wave, -dx);
}

float3 GetWaveHeight(const in float3 position, const in float skyLight, const in float time, const in uint iterations) {
    float iter = 0.0;           // this will help generating well distributed wave directions
    float weight = 1.0;         // weight in final sum for the wave, this will change every iteration
    float frequency = 0.85;      // frequency of the wave, this will change every iteration
    float timeMultiplier = 2.5; // time multiplier for the wave, this will change every iteration

    float DRAG_MULT = 0.22 * settings.Water_WaveHeight;
    float wavePhaseShift = length(position) * 0.1;
    
    float3 wavePos = position;
    wavePos.y /= settings.Water_WaveHeight;
    float weightSum = 0.0;
    float valueSum = 0.0;

    for (uint i = 0; i < iterations; i++) {
        float iterMod = fmod(iter, PI * 2.0);
        float2 p = float2(sin(iterMod), cos(iterMod));

        float2 octave = waveDx(wavePos.xz, p, frequency, time * timeMultiplier + wavePhaseShift);
        wavePos.xz += p * octave.y * weight * DRAG_MULT;

        valueSum += octave.x * weight;
        weightSum += weight;

        iter += 1232.399963;
        timeMultiplier *= 1.07;
        frequency *= 1.18;
        weight *= 0.82;
    }

    float heightDelta = (valueSum / max(weightSum, 0.000001));
    wavePos.y += Scene_WaterWaveHeight * (heightDelta - WaterWaveSurfaceOffset);
    //wavePos.y -= WaterWaveSurfaceOffset;

    float high_1 = 1.0 - texWaterWaves_high.Sample((wavePos.xz) * 0.17 - 0.04*time);
    float high_2 = 1.0 - texWaterWaves_high.Sample((wavePos.xz) * 0.13 + 0.04*time);
    float high = 1.0 - high_1 * high_2;

    wavePos.y += 0.1 * high;

    float3 delta = wavePos;
    delta.y *= settings.Water_WaveHeight;
    delta -= position;

    return delta;
}

uint GetWaveOctaveCount(const in float viewDist) {
    float value = lerp(settings.Water_WaveDetail, 6.0, saturate(viewDist / 160.0));
    return clamp(int(value), 1, 32);
}
