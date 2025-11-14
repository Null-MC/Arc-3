public module R2;

// https://extremelearning.com.au/unreasonable-effectiveness-of-quasirandom-sequences/

float2 GetR2_1D(const in float seed) {
    const float G = 1.6180339887498948482;
    const float2 INV = rcp(G);

    return frac(INV * seed + 0.5);
}

float2 GetR2_2D(const in float seed) {
    const float G = 1.32471795724474602596;
    const float2 INV2 = rcp(float2(G, G*G));

    return frac(INV2 * seed + 0.5);
}
