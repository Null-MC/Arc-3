public module sky;

import lib.ACES;


struct SkyParameters {
    // These are per megameter.
    float3 ozoneAbsorptionBase;
    float3 rayleighScatteringBase;
    float rayleighAbsorptionBase;
    float mieScatteringBase;
    float mieAbsorptionBase;
};

static const SkyParameters skyClear = {
    ACES_linear_to_cg(float3(0.850, 1.581, 0.285)),
    ACES_linear_to_cg(float3(6.605, 12.344, 29.412)),
    0.0,
    3.996,
    4.4,
};

static const SkyParameters skyRain = {
    ACES_linear_to_cg(float3(0.650, 1.381, 0.576)),
    0.2*ACES_linear_to_cg(float3(80.802, 130.558, 200.1)),
    2.0,
    3.996,
    4.4,
};

static const SkyParameters skyEnd = {
    ACES_linear_to_cg(float3(0.650, 8.381, 8.576)),
    ACES_linear_to_cg(float3(64.802, 6.558, 28.1)),
    6.0,
    3.996 * 4.0,
    4.4 * 10.0,
};

void lerp(const in SkyParameters a, const in SkyParameters b, float f, out SkyParameters dest) {
    dest.ozoneAbsorptionBase = lerp(a.ozoneAbsorptionBase, b.ozoneAbsorptionBase, f);
    dest.rayleighScatteringBase = lerp(a.rayleighScatteringBase, b.rayleighScatteringBase, f);
    dest.rayleighAbsorptionBase = lerp(a.rayleighAbsorptionBase, b.rayleighAbsorptionBase, f);
    dest.mieScatteringBase = lerp(a.mieScatteringBase, b.mieScatteringBase, f);
    dest.mieAbsorptionBase = lerp(a.mieAbsorptionBase, b.mieAbsorptionBase, f);
}
