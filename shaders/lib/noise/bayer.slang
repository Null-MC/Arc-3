public module bayer;

static const float4x4 BayerSamples = float4x4(
    0.0000, 0.5000, 0.1250, 0.6250,
    0.7500, 0.2200, 0.8750, 0.3750,
    0.1875, 0.6875, 0.0625, 0.5625,
    0.9375, 0.4375, 0.8125, 0.3125);

float GetBayerValue(const in int2 position) {
    int2 offset = position % 4;
    return BayerSamples[offset.x][offset.y];
}
