import aperture;
import lib.common;


Sampler2D<float4> texSource;

static const float3x3 REC2020_TO_SRGB = float3x3(
    1.6605, -0.5876, -0.0728,
    -0.1246, 1.1329, -0.0083,
    -0.0182, -0.1006, 1.1187);

static const float3x3 LINEAR_RGB_TO_REC2020 = float3x3(
    0.6274, 0.3293, 0.0433,
    0.0691, 0.9195, 0.0113,
    0.0164, 0.0880, 0.8956);

float3 tonemap_ACESFit2(const in float3 color) {
    static const float3x3 m1 = float3x3(
        0.59719, 0.35458, 0.04823,
        0.07600, 0.90834, 0.01566,
        0.02840, 0.13383, 0.83777);

    static const float3x3 m2 = float3x3(
        1.60475, -0.53108, -0.07367,
        -0.10208, 1.10813, -0.00605,
        -0.00327, -0.07276, 1.07602);

    float3 v = mul(m1, color);
    float3 a = v * (v + 0.0245786) - 0.000090537;
    float3 b = v * (0.983729 * v + 0.4329510) + 0.238081;
    return saturate(mul(m2, a / b));
}

float3 tonemap_uchimura(float3 x, float P, float a, float m, float l, float c, float b) {
    float l0 = ((P - m) * l) / a;
    float L0 = m - m / a;
    float L1 = m + (1.0 - m) / a;
    float S0 = m + l0;
    float S1 = m + a * l0;
    float C2 = (a * P) / (P - S1);
    float CP = -C2 / P;

    float3 w0 = 1.0 - smoothstep(0.0, m, x);
    float3 w2 = step(m + l0, x);
    float3 w1 = 1.0 - w0 - w2;

    float3 T = m * pow(x / m, c) + b;
    float3 S = P - (P - S1) * exp(CP * (x - S0));
    float3 L = m + a * (x - m);

    return T * w0 + L * w1 + S * w2;
}


[[shader("fragment")]]
float4 applyTonemap(float2 pos : SV_Position) : SV_Target0 {
    float3 color = texSource[int2(pos)].rgb;

    color = mul(LINEAR_RGB_TO_REC2020, color);

    // color = tonemap_ACESFit2(color);

    color = tonemap_uchimura(color,
        1.000,  // max display brightness
        settings.ToneMap_Contrast,  // contrast
        0.140,  // linear section start
        0.320,  // linear section length
        1.560,  // black
        0.002); // pedestal

    color = mul(REC2020_TO_SRGB, color);

    return float4(color, 1.0);
}
