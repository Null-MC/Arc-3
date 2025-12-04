public module BRDF;

import lib.common;
import lib.light.fresnel;


float3 GetAreaLightDir(const in float3 viewNormal, const in float3 viewDir, const in float3 lightDir, const in float lightDist, const in float lightSize) {
    float3 r = reflect(viewDir, viewNormal);
    float3 L = lightDir * lightDist;
    float3 centerToRay = dot(L, r) * r - L;
    float3 closestPoint = centerToRay * saturate(lightSize / length(centerToRay)) + L;
    return normalize(closestPoint);
}

half GetLightAttenuation_Linear(const in half lightDist, const in half lightRange) {
    half lightDistF = lightDist / lightRange;
    lightDistF = (half)1.0 - saturate(lightDistF);
    return pow5(lightDistF);
}

half GetLightAttenuation_invSq(const in half lightDist, const in half lightRadius) {
    return rcp((lightDist*lightDist) + lightRadius);
}

half GetLightAttenuation(const in half lightDist, const in half lightRange, const in half lightRadius) {
    half linear = GetLightAttenuation_Linear(lightDist, lightRange);
    half invSq = GetLightAttenuation_invSq(max(lightDist-lightRadius, (half)0.0), lightRadius);

    half f = saturate(lightDist / lightRange);
    return lerp(invSq, linear, f);
}

half SampleLightDiffuse(const in float NoV, const in float NoL, const in float LoH, const in half roughL) {
    half f90 = (half)(0.5 + 2.0*roughL * pow2(LoH));
    half light_scatter = F_schlick(NoL, (half)1.0, f90);
    half view_scatter = F_schlick(NoV, (half)1.0, f90);
    return light_scatter * view_scatter;// / PI;
}

float D_GGX(const in float NoH, const in float roughL) {
    float a2 = roughL * roughL;
    float f = (NoH * a2 - NoH) * NoH + 1.0;
    return a2 / (PI * f * f);
}

// half D_GGX(const in half NoH, const in half roughL) {
//     half a2 = pow2(roughL);
//     half f = (NoH * a2 - NoH) * NoH + (half)1.0;
//     return a2 / ((half)PI * f*f);
// }

float V_SmithGGXCorrelated(float NdotL, float NdotV, float roughness) {
    float a = roughness * roughness;
    float k = (a + 1.0) * (a + 1.0) / 8.0;
    float G_V = NdotV / (NdotV * (1.0 - k) + k);
    float G_L = NdotL / (NdotL * (1.0 - k) + k);
    return G_V * G_L;
}

// half V_SmithGGXCorrelated(half NdotL, half NdotV, half roughness) {
//     half a = pow2(roughness);
//     half k = (a + (half)1.0) * (a + (half)1.0) / (half)8.0;
//     half G_V = NdotV / (NdotV * ((half)1.0 - k) + k);
//     half G_L = NdotL / (NdotL * ((half)1.0 - k) + k);
//     return G_V * G_L;
// }

float3 SampleLightSpecular(float NoL, float NoH, float NoV, half3 F_VoH, half roughL) {
    float D = D_GGX(NoH, roughL);
    float G = V_SmithGGXCorrelated(NoL, NoV, roughL);

    float3 numerator = saturate(D * G * F_VoH);
    // float3 numerator = max(D * G * F_VoH, 0.0);
    float denominator = 4.0 * NoL * NoV + 0.0001;
    return numerator / denominator;
}

// half3 SampleLightSpecular(half NoL, half NoH, half NoV, half3 F_VoH, half roughL) {
//     half D = D_GGX(NoH, roughL);
//     half G = V_SmithGGXCorrelated(NoL, NoV, roughL);

//     half3 numerator = saturate(D * G * F_VoH);
//     half denominator = (half)4.0 * NoL * NoV + (half)0.0001;
//     return numerator / half3(denominator);
// }
