import lib.light.fresnel;
import lib.light.brdf;


struct SurfaceData {
    float3 skyPos;
    float3 normal;
    half3 f0;
    float roughL;
    half3 tint;
};

struct CelestialLight {
    float3 localDir;
    half3 color;
};

void SampleCelestial(inout half3 diffuse, inout half3 specular, CelestialLight light, SurfaceData surface, float3 viewDir, float NoVm) {
    float3 H = normalize(light.localDir + viewDir);

    float NoLm = max(dot(surface.normal, light.localDir), 0.0);
    float NoHm = max(dot(surface.normal, H), 0.0);
    float LoHm = max(dot(light.localDir, H), 0.0);
    float VoHm = max(dot(viewDir, H), 0.0);

    //float3 F_VoH = material_fresnel(albedo, f0_metal, roughL, VoHm);
    half3 F_VoH = F_schlickRough(VoHm, surface.f0, surface.roughL);

    float D = SampleLightDiffuse(NoVm, NoLm, LoHm, surface.roughL);
    diffuse += NoLm * D * light.color * saturate(1.0 - F_VoH);

    half3 S = SampleLightSpecular(NoLm, NoHm, NoVm, F_VoH, surface.roughL);
    specular += NoLm * S * light.color;// * surface.tint;
}
