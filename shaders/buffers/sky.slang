public module sky;

struct SkyParameters {
    // These are per megameter.
    float3 ozoneAbsorptionBase;
    float3 rayleighScatteringBase;
    float rayleighAbsorptionBase;
    float mieScatteringBase;
    float mieAbsorptionBase;
};

static const SkyParameters skyClear = {
    float3(0.850, 1.581, 0.285),
    float3(6.605, 12.344, 29.412),
    0.0,
    3.996,
    4.4,
};

static const SkyParameters skyRain = {
    float3(0.650, 1.381, 0.576),
    0.2*float3(80.802, 130.558, 200.1),
    2.0,
    3.996 * 12.0,
    4.4 * 12.0,
};

static const SkyParameters skyEnd = {
    float3(0.650, 8.381, 8.576),
    float3(64.802, 6.558, 28.1),
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
