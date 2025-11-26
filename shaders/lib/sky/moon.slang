public module moon;

import aperture;
import lib.common;
import lib.matrix;
import lib.sampling.ERP;
import lib.sampling.dfd_normal;
import lib.light.fresnel;

static const float moon_radiusKm = 1737.4;
static const float moon_distanceKm = 384400.0 * 0.3;

// static const float moon_AreaDist = 100.0;
// static const float moon_AreaSize = 8.0;

static const float moon_surfaceDepthKm = 80.0;
static const float moon_rotationSpeed = 0.0064;
static const float moon_axisTilt = -0.6;
static const float moon_roughL = 0.92;
static const float moon_f0 = 0.136;

Sampler2D texMoon;


float3 renderMoon(const in float3 viewLocalDir, const in float3 moonLocalPos, const in float moonHitDist, const in bool isReflection) {
    float3 hitPos = viewLocalDir * moonHitDist;
    float3 hitNormal = normalize(hitPos - moonLocalPos);
    if (isReflection) hitNormal = -hitNormal;

    float3x3 matAxisRot = rotateZ(moon_axisTilt);
    hitNormal = mul(hitNormal, matAxisRot);

    float2 erp_uv = DirectionToUV(hitNormal);
    erp_uv.x += moon_rotationSpeed * ap.timing.timeElapsed;

    float4 albedo_height = texMoon.SampleLevel(erp_uv, 0);
    float3 albedo = RgbToLinear(albedo_height.rgb);

    hitPos += moon_surfaceDepthKm * albedo_height.a * hitNormal;

    float3 normal = getSurfaceNormal(hitPos, hitNormal);
    if (isReflection) normal = -normal;

    const float3 fakeSunDir = normalize(float3(0.4, -1.0, 0.2));

    float3 H = normalize(-viewLocalDir + fakeSunDir);

    float NoLm = max(dot(normal, fakeSunDir), 0.0);
    float NoVm = max(dot(normal, -viewLocalDir), 0.0);
    float NoHm = max(dot(normal, H), 0.0);
    float LoHm = max(dot(fakeSunDir, H), 0.0);
    float VoHm = max(dot(-viewLocalDir, H), 0.0);

    // float F = F_schlickRough(VoHm, moon_f0, moon_roughL);
    float F_NoV = F_schlickRough(NoVm, moon_f0, moon_roughL);
    // float D = SampleLightDiffuse(NoVm, NoLm, LoHm, moon_roughL) * (1.0 - F);
    // float S = SampleLightSpecular(NoLm, NoHm, NoVm, F, moon_roughL);
    // return MOON_LUMINANCE * NoLm * (D * albedo + S) * scene.sunColor;
    return NoLm * scene[0].MoonColor * (1.0 - F_NoV) * albedo;
}
