public module wind_waving;

import aperture;
import lib.common;
import lib.tags;
import lib.noise.hash;

extern static const bool Sky_WindEnabled;

static const float wavingScale = 16.0;
static const float wavingHeight = 0.6;
static const float Wind_Variation = 0.1 * PI;

float3 waving_fbm(const in float3 worldPos, const in float time) {
    float2 position = worldPos.xz / wavingScale;

    float iter = 0.0;
    float frequency = 3.0;
    float speed = 1.0;
    float weight = 1.0;
    float height = 0.0;
    float waveSum = 0.0;

    // float time = ap.timing.timeElapsed / 3.6 * 3.0;
    // time += Wind_Variation * time_dither;
    
    [ForceUnroll]
    for (int i = 0; i < 4; i++) {
        float2 direction = float2(sin(iter), cos(iter));
        float x = dot(direction, position) * frequency + time * speed;
        x = fmod(x, 2.0 * PI);

        float wave = exp(sin(x) - 1.0);
        float result = wave * cos(x);
        float2 force = result * weight * direction;
        
        position -= force * 0.24;
        height += wave * weight;
        iter += 0.33;
        waveSum += weight;
        weight *= 0.8;
        frequency *= 1.1;
        speed *= 1.3;
    }

    position = ((position * wavingScale) - worldPos.xz) / wavingScale;
    float3 offset = float3(position.x, 0.0, position.y);
    return -offset;
}

float3 GetWavingOffset(const in float3 origin_worldPos, const in float3 midPos, const in uint blockTags, const in float timeElapsed) {
    float3 position_seed = origin_worldPos;
    if ((blockTags & TAG_WAVING_FULL) == TAG_WAVING_FULL) position_seed.y = 0.0;
    float time_dither = hash13(position_seed);

    float waving_strength = 0.4;
    waving_strength = lerp(waving_strength, 1.8, ap.world.rainStrength);
    // waving_strength = lerp(waving_strength, 3.2, ap.world.thunderStrength);

    float time = timeElapsed / 3.6 * 3.0;
    time += Wind_Variation * time_dither;

    float3 offset_new = waving_fbm(origin_worldPos, time) * waving_strength;

    float3 offsetFinal = 0.0;
    if ((blockTags & TAG_WAVING_FULL) == TAG_WAVING_FULL) {
        // no attach
        offsetFinal = offset_new;
    }
    else if ((blockTags & TAG_WAVING_GROUND) == TAG_WAVING_GROUND) {
        // ground attach
        float attach_dist = 0.5 - midPos.y;

        if (attach_dist > 0.0) {
            float3 new_pos = float3(offset_new.x, attach_dist, offset_new.z);

            new_pos *= attach_dist / length(new_pos);
            new_pos.y -= attach_dist;

            offsetFinal = new_pos;
        }
    }

    return offsetFinal;
}
