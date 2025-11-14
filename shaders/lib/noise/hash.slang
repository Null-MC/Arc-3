public module hash;

static const float4 U = float4(0.1031, 0.1030, 0.0973, 0.1099);

float hash11(const in float seed) {
    float p = fract(seed * U.x);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

float hash12(const in float2 seed) {
    float3 p3  = fract(seed.xyx * U.x);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float hash13(const in float3 seed) {
    float3 p3 = fract(seed * U.x);
    p3 += dot(p3, p3.zyx + 33.33); // 31.32
    return fract((p3.x + p3.y) * p3.z);
}

float2 hash22(const in float2 seed) {
    float3 p3 = fract(seed.xyx * U.xyz);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

float2 hash23(const in float3 seed) {
    float3 p3 = fract(seed * U.xyz);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

float3 hash31(const in float seed) {
   float3 p3 = fract(seed * U.xyz);
   p3 += dot(p3, p3.yzx + 33.33);
   return fract((p3.xxy + p3.yzz) * p3.zyx); 
}

float3 hash32(const in float2 seed) {
    float3 p3 = fract(seed.xyx * U.xyz);
    p3 += dot(p3, p3.yxz + 33.33);
    return fract((p3.xxy + p3.yzz) * p3.zyx);
}

float3 hash33(const in float3 seed) {
    float3 p3 = fract(seed * U.xyz);
    p3 += dot(p3, p3.yxz + 33.33);
    return fract((p3.xxy + p3.yxx) * p3.zyx);
}

float4 hash41(const in float seed) {
    float4 p4 = fract(seed * U);
    p4 += dot(p4, p4.wzxy + 33.33);
    return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

float4 hash42(const in float2 seed) {
    float4 p4 = fract(seed.xyxy * U);
    p4 += dot(p4, p4.wzxy + 33.33);
    return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

float4 hash44(const in float4 seed) {
    float4 p4 = fract(seed * U);
    p4 += dot(p4, p4.wzxy + 33.33);
    return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}
