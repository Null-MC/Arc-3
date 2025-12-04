public module fresnel;

import lib.common;

float3 F0ToIor(const in float3 f0, const in float3 medium) {
    float3 sqrt_f0 = sqrt(max(f0, EPSILON));
    return (medium + sqrt_f0) / max(medium - sqrt_f0, EPSILON);
}

float F0ToIor(const in float f0, const in float medium) {
    float sqrt_f0 = sqrt(max(f0, EPSILON));
    return (medium + sqrt_f0) / max(medium - sqrt_f0, EPSILON);
}

// T F0ToIor<T>(const in T f0, const in T medium) where T: IArithmetic {
//     T sqrt_f0 = sqrt(max(f0, T(EPSILON)));
//     return (medium + sqrt_f0) / max(medium - sqrt_f0, EPSILON);
// }

float3 IorToF0(const in float3 ior, const in float3 medium) {
    float3 t = (ior - medium) / (ior + medium);
    return t*t;
}

float IorToF0(const in float ior, const in float medium) {
    float t = (ior - medium) / (ior + medium);
    return t*t;
}

float F_schlick(const in float cos_theta, const in float f0, const in float f90) {
    float invCosTheta = saturate(1.0 - cos_theta);
    return f0 + (f90 - f0) * pow5(invCosTheta);
}

float3 F_schlick(const in float cos_theta, const in float3 f0, const in float3 f90) {
    float invCosTheta = saturate(1.0 - cos_theta);
    return f0 + (f90 - f0) * pow5(invCosTheta);
}

half F_schlick(const in float cos_theta, const in half f0, const in half f90) {
    float invCosTheta = saturate(1.0 - cos_theta);
    return f0 + (f90 - f0) * (half)pow5(invCosTheta);
}

half get_f82(const in half f0) {
    return (half)((2371179624770769.0 * f0 + 2041666790000000.0) / 4412846414770769.0);
}

half3 get_f82(const in half3 f0) {
    return (half3)((2371179624770769.0 * f0 + 2041666790000000.0) / 4412846414770769.0);
}

float F_Lazanyi2019(const in float cosTheta, const in float f0, const in float f82) {
    // This is unpolarized ONLY
    // float f82 = (2371179624770769.0 * f0 + 2041666790000000.0) / 4412846414770769.0;
    float a = 17.6513846 * (f0 - f82) + 8.16666667 * (1.0 - f0);
    return saturate(f0 + (1.0 - f0) * pow5(1.0 - cosTheta) - a * cosTheta * pow6(1.0 - cosTheta));
}

float3 F_Lazanyi2019(const in float3 cosTheta, const in float3 f0, const in float3 f82) {
    // This is unpolarized ONLY
    // float3 f82 = (2371179624770769.0 * f0 + 2041666790000000.0) / 4412846414770769.0;
    float3 a = 17.6513846 * (f0 - f82) + 8.16666667 * (1.0 - f0);
    return saturate(f0 + (1.0 - f0) * pow5(1.0 - cosTheta) - a * cosTheta * pow6(1.0 - cosTheta));
}
