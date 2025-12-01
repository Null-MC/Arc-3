import aperture;
import buffers.ObjectData;
import lib.common;
import lib.blocks;
import lib.light.fresnel;
import lib.light.brdf;
import lib.light.HG;
import lib.material.pbr;
import lib.material.rough_normal;
import lib.water.wetness;
import lib.sky.common;
import lib.sky.sun;
import lib.sky.moon;
import lib.sky.scattering;
import lib.sky.sample_transmit;
import lib.sky.sample_irradiance;
import lib.sky.sample_view;
import lib.sky.sample_light;

extern static const int ReflectMode;
extern static const bool Reflect_Rough;
extern static const bool Lighting_GI;
extern static const bool RENDER_TRANSLUCENT = false;

Sampler2D<float> texDepth;

Sampler2D<half4> texAlbedoGB;
Sampler2D<uint2> texNormalGB;
Sampler2D<uint2> texMatLightGB;

Sampler2D<half2> texWetnessGB;
Sampler2D<half3> texShadowFinal;
Sampler2D<half3> texSssFinal;


struct FragmentOutput {
    half3 diffuse : SV_Target0;
    half3 specular : SV_Target1;
};

[[shader("fragment")]]
FragmentOutput lightingSky(float2 pos : SV_Position) {
    float3 diffuse = 0.0;
    float3 specular = 0.0;
    
    uint2 uv = uint2(pos);
    float depth = texDepth[uv];
    half4 colorData = texAlbedoGB[uv];
    
    if (depth < 1.0 && colorData.a > 0.0) {
        ObjectData_Normals normals;
        normals.unpack(texNormalGB[uv]);

        ObjectData_MatLit mat_lit;
        mat_lit.unpack(texMatLightGB[uv]);

        float2 texcoord = pos / ap.game.screenSize;
        if (TAA_Enabled) texcoord -= scene[0].taa_jitter;

        float3 ndcPos = float3(texcoord, depth) * 2.0 - 1.0;

        if (mat_lit.blockMapId == BLOCK_HAND) {
            ndcPos.z /= MC_HAND_DEPTH;
        }

        float3 localPos = project(scene[0].viewProjectionInv, ndcPos);
        float3 viewLocalDir = -normalize(localPos);

        half3 albedo = RgbToLinear(colorData.rgb);
        half roughness = mat_roughness(mat_lit.specular.r);
        half f0_metal = mat_f0_metal(mat_lit.specular.g);
        half sss = mat_sss(mat_lit.specular.b);

        // float roughL = roughness*roughness;

        // float3 geo_normal = normalize(unpackUnorm4x8ToFloat(normalData.r).xyz * 2.0 - 1.0);
        // float3 tex_normal = normalize(unpackUnorm4x8ToFloat(normalData.g).xyz * 2.0 - 1.0);

        // half4 lightData = unpackUnorm4x8ToHalf(matLightData.g);
        //float2 lmcoord = light.rg;
        half lmcoord_y = pow2(mat_lit.lmcoord.y);
        // float occlusion = lightData.b;

        half metalness = mat_metalness(f0_metal);
        
        // TODO: wetness
        half2 wetness_puddle = texWetnessGB[uv];
        Wetness_ApplyRoughness(roughness, wetness_puddle.x);
        Wetness_ApplyNormal(normals.tex, normals.geo, wetness_puddle.y);
        // f0_metal = (half)lerp(f0_metal, 0.02, wetness);

        SurfaceData surface;
        surface.skyPos = getSkyPosition(localPos);
        surface.normal = normals.tex;
        surface.roughL = roughness*roughness;
        surface.f0 = lerp(f0_metal, albedo, metalness);

        half NoVm = max((half)dot(normals.tex, viewLocalDir), (half)0.0);
        
        half3 shadow = RgbToLinear(texShadowFinal[uv]);
        bool shadowIsSun = dot(ap.celestial.position, ap.celestial.sunPosition) > 0.0;

        float3 sun_color = scene[0].SunColor * sampleSkyTransmit(surface.skyPos, scene[0].SunLocalDir);
        // sun_color *= atmosAbsorb(surface.skyPos, scene[0].SunLocalDir);
        
        float3 moon_color = scene[0].MoonColor * sampleSkyTransmit(surface.skyPos, scene[0].MoonLocalDir);
        // moon_color *= atmosAbsorb(surface.skyPos, scene[0].MoonLocalDir);
        
        CelestialLight sun;
        sun.localDir = GetAreaLightDir(normals.tex, viewLocalDir, scene[0].SunLocalDir, sun_distanceMm, sun_radiusMm);
        // sun.localDir = scene[0].SunLocalDir;
        sun.color = sun_color * (shadowIsSun ? shadow : (half)0.0);
        SampleCelestial(diffuse, specular, sun, surface, viewLocalDir, NoVm);

        CelestialLight moon;
        moon.localDir = GetAreaLightDir(normals.tex, viewLocalDir, scene[0].MoonLocalDir, moon_distanceKm, moon_radiusKm);
        // moon.localDir = scene[0].MoonLocalDir;
        moon.color = moon_color * (shadowIsSun ? (half)0.0 : shadow);
        SampleCelestial(diffuse, specular, moon, surface, viewLocalDir, NoVm);

        // Ambient from Sky Irradiance
        if (!Lighting_GI || RENDER_TRANSLUCENT) {
            half3 sky_ambient = sampleSkyIrradiance(normals.tex);
            diffuse += sky_ambient * lmcoord_y * mat_lit.occlusion;
        }

        // Subsurface Scattering
        float VoL = dot(-viewLocalDir, scene[0].SkyLightLocalDir);
        float sss_phase = saturate(HG(VoL, 0.3));
        half3 sss_sky = RgbToLinear(texSssFinal[uv]);
        half3 sssFinal = sss_sky * (sun_color + moon_color) * sss_phase;
         
        if (!Lighting_GI || RENDER_TRANSLUCENT) {
            // half3 sss_ambient = sampleSkyIrradiance(-normals.tex) * lmcoord_y;
            half3 sss_ambient = sampleSkyIrradiance(-viewLocalDir);
            sssFinal += 0.3 * sss_ambient * lmcoord_y;
        }

        // float NoLm = max(dot(normals.tex, scene[0].SkyLightLocalDir), 0.0);
        // diffuse = lerp(diffuse, sssFinal, sss * (1.0 - NoLm));
        // diffuse *= 1.0 - 0.3*sss;
        diffuse += 3.0*sssFinal*sss;
        // diffuse = lerp(diffuse, 3.0 * sssFinal, 0.5*sss);


        diffuse /= PI;

        if (ReflectMode == Reflect_SkyOnly) {
            float3 reflectLocalNormal = normals.tex;
            if (Reflect_Rough) reflectLocalNormal = randomizeNormal(uint2(pos), normals.tex, surface.roughL);

            float3 viewPos = project(ap.camera.projectionInv, ndcPos);
            float3 fragViewDir = normalize(viewPos);

            float3 viewNormal = mul(float3x3(ap.camera.view), reflectLocalNormal);
            float3 reflectViewDir = reflect(fragViewDir, viewNormal);
            
            float3 reflectLocalDir = mul(float3x3(ap.camera.viewInv), reflectViewDir);
            reflectLocalDir = normalize(reflectLocalDir);

            half3 skyColor = sampleSkyView(surface.skyPos, reflectLocalDir, scene[0].SunLocalDir);
            half3 F_NoV = F_Lazanyi2019(NoVm, surface.f0);
            specular += F_NoV * skyColor * (((half)1.0 - surface.roughL) * lmcoord_y);
            diffuse *= 1.0 - F_NoV;
        }
    }

    FragmentOutput output;
    output.diffuse = half3(diffuse);
    output.specular = half3(specular);
    return output;
}
