import aperture;
import buffers.OpaqueObject;
import lib.common;
import lib.light.fresnel;
import lib.light.brdf;
import lib.material.pbr;
import lib.material.rough_normal;
import lib.sky.common;
import lib.sky.sun;
import lib.sky.moon;
import lib.sky.sample_transmit;
import lib.sky.sample_irradiance;
import lib.sky.sample_view;
import lib.sky.sample_light;

extern static const int ReflectMode;

Sampler2D<float> solidDepthTex;

Sampler2D<half4> texAlbedoGB;
Sampler2D<uint2> texNormalGB;
Sampler2D<uint2> texMatLightGB;
Sampler2D<half3> texShadowFinal;
Sampler2D<half3> texSssFinal;


struct FragmentOutput {
    half3 diffuse : SV_Target0;
    half3 specular : SV_Target1;
};

[[shader("fragment")]]
FragmentOutput lightingSky(float2 pos : SV_Position) {
    FragmentOutput output;
    output.diffuse = half3(0.0);
    output.specular = half3(0.0);
    
    uint2 uv = uint2(pos);
    float depth = solidDepthTex[uv];
    
    if (depth < 1.0) {
        float2 texcoord = pos / ap.game.screenSize;
        if (TAA_Enabled) texcoord -= scene[0].taa_jitter;

        float3 clipPos = float3(texcoord, depth) * 2.0 - 1.0;
        float3 viewPos = project(ap.camera.projectionInv, clipPos);
        float3 localPos = mul3(ap.camera.viewInv, viewPos);
        float3 viewLocalDir = -normalize(localPos);

        half4 colorData = texAlbedoGB[uv];

        OpaqueObject_Normals normals;
        normals.unpack(texNormalGB[uv]);

        OpaqueObject_MatLit mat_lit;
        mat_lit.unpack(texMatLightGB[uv]);

        half3 albedo = RgbToLinear(colorData.rgb);
        float roughness = mat_roughness(mat_lit.specular.r);
        float f0_metal = mat_f0_metal(mat_lit.specular.g);
        float sss = mat_sss(mat_lit.specular.b);

        // float roughL = roughness*roughness;

        // float3 geo_normal = normalize(unpackUnorm4x8ToFloat(normalData.r).xyz * 2.0 - 1.0);
        // float3 tex_normal = normalize(unpackUnorm4x8ToFloat(normalData.g).xyz * 2.0 - 1.0);

        // half4 lightData = unpackUnorm4x8ToHalf(matLightData.g);
        //float2 lmcoord = light.rg;
        float lmcoord_y = pow2(mat_lit.lmcoord.y);
        // float occlusion = lightData.b;

        float metalness = mat_metalness(f0_metal);
        
        SurfaceData surface;
        surface.skyPos = getSkyPosition(localPos);
        surface.normal = normals.tex;
        surface.roughL = roughness*roughness;
        surface.tint = lerp(1.0, albedo, metalness);
        surface.f0 = lerp(f0_metal, albedo, metalness);

        float NoVm = max(dot(normals.tex, viewLocalDir), 0.0);

        CelestialLight sun;
        sun.localDir = GetAreaLightDir(normals.tex, viewLocalDir, scene[0].SunLocalDir, sun_distanceMm, sun_radiusMm);
        sun.color = scene[0].SunColor * sampleSkyTransmit(surface.skyPos, sun.localDir);

        CelestialLight moon;
        moon.localDir = GetAreaLightDir(normals.tex, viewLocalDir, scene[0].MoonLocalDir, moon_distanceKm, moon_radiusKm);
        moon.color = scene[0].MoonColor * sampleSkyTransmit(surface.skyPos, moon.localDir);

        half3 sss_ambient = sampleSkyIrradiance(-normals.tex) * lmcoord_y;
        half3 sssFinal = texSssFinal[uv] * (sun.color + moon.color) + sss_ambient * sss;
        output.diffuse += sssFinal / PI;
        
        
        half3 shadow = RgbToLinear(texShadowFinal[uv]);
        bool shadowIsSun = dot(ap.celestial.position, ap.celestial.sunPosition) > 0.0;

        sun.color *= shadowIsSun ? shadow : half3(1.0);
        SampleCelestial(output.diffuse, output.specular, sun, surface, viewLocalDir, NoVm);

        moon.color *= shadowIsSun ? half3(1.0) : shadow;
        SampleCelestial(output.diffuse, output.specular, moon, surface, viewLocalDir, NoVm);

        float3 sky_ambient = sampleSkyIrradiance(normals.tex) * lmcoord_y * mat_lit.occlusion;

        output.diffuse = output.diffuse / PI + sky_ambient;
        output.specular = output.specular;

        // remove diffuse for smooth metals
        float smoothness = 1.0 - roughness;
        output.diffuse *= 1.0 - metalness * smoothness;

        if (ReflectMode == Reflect_SkyOnly) {
            float3 reflectLocalNormal = randomizeNormal(uv, normals.tex, surface.roughL);

            float3 fragViewDir = normalize(viewPos);
            float3 viewNormal = mul(float3x3(ap.camera.view), reflectLocalNormal);
            float3 reflectViewDir = reflect(fragViewDir, viewNormal);
            float3 reflectLocalDir = mul(float3x3(ap.camera.viewInv), reflectViewDir);
            reflectLocalDir = normalize(reflectLocalDir);

            half3 skyColor = sampleSkyView(surface.skyPos, reflectLocalDir, scene[0].SunLocalDir);
            half3 F_NoV = F_schlickRough(NoVm, surface.f0, surface.roughL);
            output.specular += F_NoV * skyColor * half3((1.0 - roughness) * lmcoord_y);
            output.diffuse *= half3(1.0) - F_NoV;
        }

        output.specular *= surface.tint;
    }

    return output;
}
