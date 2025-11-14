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

half F_schlick(const in float cos_theta, const in half f0, const in half f90) {
    float invCosTheta = saturate(1.0 - cos_theta);
    return f0 + (f90 - f0) * (half)pow5(invCosTheta);
}

float F_schlickRough(const in float cos_theta, const in float f0, const in float rough) {
    float invCosTheta = saturate(1.0 - cos_theta);
    return f0 + (max(1.0 - rough, f0) - f0) * pow5(invCosTheta);
}

half F_schlickRough(const in float cos_theta, const in half f0, const in half rough) {
    float invCosTheta = saturate(1.0 - cos_theta);
    return f0 + (max((half)1.0 - rough, f0) - f0) * (half)pow5(invCosTheta);
}

float3 F_schlickRough(const in float cos_theta, const in float3 f0, const in float rough) {
    float invCosTheta = saturate(1.0 - cos_theta);
    return f0 + (max(float3(1.0 - rough), f0) - f0) * pow5(invCosTheta);
}

half3 F_schlickRough(const in float cos_theta, const in half3 f0, const in half rough) {
    float invCosTheta = saturate(1.0 - cos_theta);
    return f0 + (max(half3(1.0 - rough), f0) - f0) * (half)pow5(invCosTheta);
}

// float3 ComplexFresnel(const in float3 n, const in float3 k, const in float c) {
//     float3 nn = n*n;
//     float3 kk = k*k;
//     float cc = c*c;

//     float3 nc2 = 2.0 * n*c;
//     float3 nn_kk = nn + kk;

//     float3 rs_num = nn_kk - nc2 + cc;
//     float3 rs_den = nn_kk + nc2 + cc;
//     float3 rs = rs_num / rs_den;
    
//     float3 rp_num = nn_kk*cc - nc2 + 1.0;
//     float3 rp_den = nn_kk*cc + nc2 + 1.0;
//     float3 rp = rp_num / rp_den;
    
//     return saturate(0.5 * (rs + rp));
// }
