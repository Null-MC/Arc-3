public module waves;

import aperture;
import lib.common;

static const float WaterWaveSurfaceOffset = 0.8;
static const float Scene_WaterWaveHeight = 0.8;

Sampler2D<half> texWaterWaves_g1;
Sampler2D<half> texWaterWaves_high;
Sampler2D<half2> texWaterWaves_offset;

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

float GetWaveHeight2(const in float3 localPos, const in float skyLight) {
    float2 worldPos = localPos.xz + ap.camera.position.xz;
    float2 time = float2(0.12, 0.25) * ap.timing.timeElapsed;

    float2 o1 = texWaterWaves_offset.Sample(worldPos * 0.04 + 0.2*time);
    float s1 = texWaterWaves_g1.Sample((worldPos + 2.0*o1) * 0.03 - 0.2 * time);

    float2 o2 = texWaterWaves_offset.Sample(worldPos * 0.08 + 0.2*time);
    // float s2 = texWaterWaves_high.Sample((worldPos + 0.3*o2) * 0.12 - 0.4 * time);
    
    // float low_h1 = texWaterWaves_low.Sample((worldPos + offset) * 0.1 - time);
    // float low_h2 = texWaterWaves_low.Sample((worldPos - offset) * 0.1 + time);

    // float low = low_h1 * low_h2;

    float high_1 = texWaterWaves_high.Sample((worldPos + 0.05*o2) * 0.25 - 0.2*time);
    float high_2 = texWaterWaves_high.Sample((worldPos - 0.05*o2) * 0.25 + 0.2*time);
    float high = high_1 * high_2;

    return 0.92*s1 + 0.08*high;

    // return 0.5 * low;// + 0.02 * high;


    // return texWaterWaves_g1.Sample((worldPos + 3.0*offset) * 0.03 - 0.1 * time);
        //  + 0.3*texWaterWaves_g1.Sample(worldPos.yx * 0.05 + 0.12 * time.yx);


    // float2 tex = worldPos * 0.06;
    // float total = 0.0;
    // float amp = 1.0;
    // float sum = 0.0;

    // [ForceUnroll]
    // for (int i = 0; i < 4; i++) {
    //     float H = texWaterWaves_low.Sample(tex);
    //     sum += H * amp;
    //     total += amp;
        
    //     tex *= 1.6;
    //     amp *= 0.5;
    // }

    // return sum / total;

    // float2 low_tex1 = (worldPos + offset) * 0.048 + time;
    // float2 low_tex2 = worldPos * 0.076 - time;

    // float low_h1 = texWaterWaves_low.Sample(low_tex1);
    // float low_h2 = texWaterWaves_low.Sample(low_tex2);

    // return 0.5 * (low_h1 + low_h2);
    // return low_h1;
}
