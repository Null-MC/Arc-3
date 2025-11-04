import lib.common;
import lib.light.fresnel;


float3 GetAreaLightDir(const in float3 viewNormal, const in float3 viewDir, const in float3 lightDir, const in float lightDist, const in float lightSize) {
    float3 r = reflect(viewDir, viewNormal);
    float3 L = lightDir * lightDist;
    float3 centerToRay = dot(L, r) * r - L;
    float3 closestPoint = centerToRay * saturate(lightSize / length(centerToRay)) + L;
    return normalize(closestPoint);
}

float GetLightAttenuation_Linear(const in float lightDist, const in float lightRange) {
    float lightDistF = lightDist / lightRange;
    lightDistF = 1.0 - saturate(lightDistF);
    return pow(lightDistF, 5);
}

float GetLightAttenuation_invSq(const in float lightDist, const in float lightRadius) {
    return 1.0 / ((lightDist*lightDist) + lightRadius);
}

float GetLightAttenuation(const in float lightDist, const in float lightRange, const in float lightRadius) {
    float linear = GetLightAttenuation_Linear(lightDist, lightRange);
    float invSq = GetLightAttenuation_invSq(max(lightDist-lightRadius, 0.0), lightRadius);

    float f = saturate(lightDist / lightRange);
    return lerp(invSq, linear, f);
}

float SampleLightDiffuse(const in float NoV, const in float NoL, const in float LoH, const in float roughL) {
    float f90 = 0.5 + 2.0*roughL * (LoH*LoH);
    float light_scatter = F_schlick(NoL, 1.0, f90);
    float view_scatter = F_schlick(NoV, 1.0, f90);
    return light_scatter * view_scatter;// / PI;
}

float D_GGX(const in float NoH, const in float roughL) {
    float a2 = roughL * roughL;
    float f = (NoH * a2 - NoH) * NoH + 1.0;
    return a2 / (PI * f * f);
}

float V_SmithGGXCorrelated(float NdotL, float NdotV, float roughness) {
    float a = roughness * roughness;
    float k = (a + 1.0) * (a + 1.0) / 8.0;
    float G_V = NdotV / (NdotV * (1.0 - k) + k);
    float G_L = NdotL / (NdotL * (1.0 - k) + k);
    return G_V * G_L;
}

float3 SampleLightSpecular(float NoL, float NoH, float NoV, float3 F_VoH, float roughL) {
    float D = D_GGX(NoH, roughL);
    float G = V_SmithGGXCorrelated(NoL, NoV, roughL);

    float3 numerator = clamp(D * G * F_VoH, 0.0, 1.0);
    float denominator = 4.0 * NoL * NoV + 0.0001;
    return numerator / denominator;
}
