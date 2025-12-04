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


// LAZANYI 2019

struct LazanyiF {
    half3 f0;
    half3 f82;

    __init(half3 f0, half3 f82) {
        this.f0 = f0;
        this.f82 = f82;
    }

    __init(half3 f0) {
        this.f0 = f0;
        this.f82 = LazanyiF.f82_from_f0(f0);
    }

    float A() {
        const float cosThetaMax = acos(1.0 / 7.0);
        const float max5 = pow5(cosThetaMax);

        const float denom = cosThetaMax * pow6(cosThetaMax);
        return saturate((f0.x + (1.0 - f0.x) * max5 - f82.x) / denom);
    }

    float3 F(const in float cosTheta) {
        float cosTheta_inv = saturate(1.0 - cosTheta);
        return saturate(f0 + (1.0 - f0) * pow5(cosTheta_inv) - A() * cosTheta * pow6(cosTheta_inv));
    }

    static half f82_from_f0(const in half f0) {
        return (half)((2371179624770769.0 * f0 + 2041666790000000.0) / 4412846414770769.0);
    }

    static half3 f82_from_f0(const in half3 f0) {
        return (half3)((2371179624770769.0 * f0 + 2041666790000000.0) / 4412846414770769.0);
    }
};

// float3 a = 17.6513846 * (f0 - f82) + 8.16666667 * (1.0 - f0);
// float3 f82 = (2371179624770769.0 * f0 + 2041666790000000.0) / 4412846414770769.0;

// half get_f82(const in half f0) {
//     return (half)((2371179624770769.0 * f0 + 2041666790000000.0) / 4412846414770769.0);
// }

// half3 get_f82(const in half3 f0) {
//     return (half3)((2371179624770769.0 * f0 + 2041666790000000.0) / 4412846414770769.0);
// }

// float lazanyi_a(const in float f0, const in float f82) {
//     const float cosThetaMax = acos(1.0 / 7.0);
//     const float max5 = pow5(cosThetaMax);

//     const float denom = cosThetaMax * pow6(cosThetaMax);
//     return saturate((f0 + (1.0 - f0) * max5 - f82) / denom);
// }

// float3 lazanyi_a(const in LazanyiF F) {
//     const float cosThetaMax = acos(1.0 / 7.0);
//     const float max5 = pow5(cosThetaMax);

//     const float denom = cosThetaMax * pow6(cosThetaMax);
//     return saturate((F.f0 + (1.0 - F.f0) * max5 - F.f82) / denom);
// }

// float F_Lazanyi2019(const in float cosTheta, const in LazanyiF F) {
//     float cosTheta_inv = saturate(1.0 - cosTheta);

//     float a = lazanyi_a(F);
//     return saturate(F.f0 + (1.0 - F.f0) * pow5(cosTheta_inv) - a * cosTheta * pow6(cosTheta_inv));
// }

// float3 F_Lazanyi2019(const in float cosTheta, const in LazanyiF F) {
//     float cosTheta_inv = saturate(1.0 - cosTheta);

//     return saturate(F.f0 + (1.0 - F.f0) * pow5(cosTheta_inv) - F.A() * cosTheta * pow6(cosTheta_inv));
// }
