public module sample_light;

import lib.light.fresnel;
import lib.light.brdf;


struct SurfaceData {
    float3 skyPos;
    float3 normal;
    LazanyiF lazanyi;
    half roughL;
};

struct CelestialLight {
    float3 localDir;
    half3 color;
};

void SampleCelestial(inout float3 diffuse, inout float3 specular, CelestialLight light, SurfaceData surface, float3 viewDir, half NoVm) {
    float3 H = normalize(light.localDir + viewDir);

    float NoLm = max(dot(surface.normal, light.localDir), 0.0);
    float NoHm = max(dot(surface.normal, H), 0.0);
    float LoHm = max(dot(light.localDir, H), 0.0);
    float VoHm = max(dot(viewDir, H), 0.0);

    //float3 F_VoH = material_fresnel(albedo, f0_metal, roughL, VoHm);
    half3 F_VoH = surface.lazanyi.F(VoHm);

    half D = SampleLightDiffuse(NoVm, NoLm, LoHm, surface.roughL);
    diffuse += NoLm * D * light.color;// * saturate((half)1.0 - F_VoH);

    float3 S = SampleLightSpecular(NoLm, NoHm, NoVm, F_VoH, surface.roughL);
    specular += NoLm * S * light.color;
}
