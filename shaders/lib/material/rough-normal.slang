public module rough_normal;

import aperture;

Sampler2D<float3> texBlueNoise;


float3 randomNormal(float2 uv, const in float3 normal) {
    uv = uv + float2(23, 137) * ap.timing.frameCounter;
    float3 random_normal = texBlueNoise[uv % 512];
    random_normal = normalize(random_normal * 2.0 - 1.0);

    if (dot(normal, random_normal) < 0)
        random_normal = -random_normal;

    return random_normal;
}

float3 randomizeNormal(int2 uv, const in float3 normal, const in float roughL) {
    float3 random_normal = randomNormal(uv, normal);
    return normalize(lerp(normal, random_normal, roughL));
}
