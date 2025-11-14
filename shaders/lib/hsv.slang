public module HSV;

float3 RgbToHsv(const in float3 c) {
    static const float4 K = float4(0.0, -1.0, 2.0, -3.0) / 3.0;
    static const float e = 1.0e-10;

    float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

float3 HsvToRgb(const in float3 c) {
    static const float4 K = float4(3.0, 2.0, 1.0, 9.0) / 3.0;

    float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * lerp(K.xxx, saturate(p - K.xxx), c.y);
}

// half3 RgbToHsv(const in half3 c) {
//     static const half4 K = half4(float4(0.0, -1.0, 2.0, -3.0) / 3.0);
//     static const float e = 1.0e-10;

//     half4 p = lerp(half4(c.bg, K.wz), half4(c.gb, K.xy), step(c.b, c.g));
//     half4 q = lerp(half4(p.xyw, c.r), half4(c.r, p.yzx), step(p.x, c.r));

//     half d = q.x - min(q.w, q.y);
//     return half3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
// }

// half3 HsvToRgb(const in half3 c) {
//     static const half4 K = half4(float4(3.0, 2.0, 1.0, 9.0) / 3.0);

//     half3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
//     return c.z * lerp(K.xxx, saturate(p - K.xxx), c.y);
// }
