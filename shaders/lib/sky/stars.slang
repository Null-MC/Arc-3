public module stars;

import aperture;

// https://www.shadertoy.com/view/tdSXzD

static const int Sky_StarLayers = 3; // [1 2 3 4 5]
static const float Sky_StarRes = 512.0;
static const float Sky_StarSpeed = 1.2;
static const float Sky_StarBrightness = 8.0;
static const float Sky_StarTempMin = 2000.0;
static const float Sky_StarTempMax = 16000.0;


float3 hash33_stars(in float3 p) {
    p = fract(p * float3(443.8975, 397.2973, 491.1871));
    p += dot(p.zxy, p.yxz + 19.27);
    return fract(float3(p.x * p.y, p.z*p.x, p.y*p.z));
}

// float noise(const in vec2 v) { 
//     return textureLod(noisetex, (v + 0.5) / 256.0, 0.0).r; 
// }

float3 getStarViewDir(const in float3 localViewDir) {
    float sunAngle = mod(ap.world.time / 24000.0, 1.0);

    float3x3 matAngleRot = rotateX(-radians(Sky_sunPathRotation));
    float3x3 matTimeRot = rotateZ(TAU * sunAngle * Sky_StarSpeed);
    return matTimeRot * (matAngleRot * localViewDir);
}

float3 GetStarLight(const in float3 viewDir) {
    const float StarTempRange = Sky_StarTempMax - Sky_StarTempMin;

    float3 final = float3(0.0);
    float3 D1 = viewDir;

	for (int i = 0; i < Sky_StarLayers; i++) {
        float3 q = fract(D1 * Sky_StarRes) - 0.5;
        float3 id = floor(D1 * Sky_StarRes);
        float2 rn = hash33_stars(id).xy;
        float c2 = 1.0 - smoothstep(0.0, 0.6, length(q));
        c2 *= step(rn.x, 0.0007 + i * 0.002);

        float layer_scale = 1.0 / (1.0 + i+rn.y);
        float temp = StarTempRange * pow(layer_scale, 2.0) + Sky_StarTempMin;
        float falloff = c2 * pow(layer_scale, 3.0);

        final += blackbody(temp) * falloff;

        D1 *= 1.2;
    }

    return final * Sky_StarBrightness;
}
