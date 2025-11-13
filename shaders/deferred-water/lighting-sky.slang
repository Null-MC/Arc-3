import aperture;
import buffers.ObjectData;
import lib.common;
import lib.light.fresnel;
import lib.light.brdf;
import lib.material.pbr;
import lib.material.rough_normal;
import lib.sampling.depth;
import lib.sky.common;
import lib.sky.sun;
import lib.sky.moon;
import lib.sky.sample_transmit;
import lib.sky.sample_irradiance;
import lib.sky.sample_view;
import lib.sky.sample_light;
import lib.water.water_depth;
import lib.shadow;

extern static const int ReflectMode;

// Sampler2D<float> texDepth;

// Sampler2D<half4> texAlbedoGB_water;
// Sampler2D<uint2> texNormalGB_water;
// Sampler2D<uint2> texMatLightGB_water;

// Sampler2D<half3> texShadowFinal;
// Sampler2D<half3> texSssFinal;


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
    float depthL = WaterDepth_get(uv);
    float depth = delinearizeDepth(depthL, ap.camera.near, ap.camera.far) * 0.5 + 0.5;
    
    if (depth < 1.0) {
        half4 colorData = texAlbedoGB_water[uv];

        float2 texcoord = pos / ap.game.screenSize;
        if (TAA_Enabled) texcoord -= scene[0].taa_jitter;

        float3 clipPos = float3(texcoord, depth) * 2.0 - 1.0;
        float3 viewPos = project(ap.camera.projectionInv, clipPos);
        float3 localPos = mul3(ap.camera.viewInv, viewPos);
        float3 viewLocalDir = -normalize(localPos);

        ObjectData_Normals normal;
        normal.unpack(texNormalGB_water[uv]);

        ObjectData_MatLit mat_lit;
        mat_lit.unpack(texMatLightGB_water[uv]);

        half3 albedo = RgbToLinear(colorData.rgb);
        half roughness = mat_roughness(mat_lit.specular.r);
        half f0_metal = mat_f0_metal(mat_lit.specular.g);
        // half sss = mat_sss(mat_lit.specular.b);

        // float roughL = roughness*roughness;

        // float3 geo_normal = normalize(unpackUnorm4x8ToFloat(normalData.r).xyz * 2.0 - 1.0);
        // float3 tex_normal = normalize(unpackUnorm4x8ToFloat(normalData.g).xyz * 2.0 - 1.0);

        // half4 lightData = unpackUnorm4x8ToHalf(matLightData.g);
        //float2 lmcoord = light.rg;
        half lmcoord_y = pow2(mat_lit.lmcoord.y);
        // float occlusion = lightData.b;

        // half metalness = mat_metalness(f0_metal);
        
        SurfaceData surface;
        surface.skyPos = getSkyPosition(localPos);
        surface.normal = normal.tex;
        surface.roughL = roughness*roughness;
        surface.f0 = f0_metal;

        float NoVm = max(dot(normal.tex, viewLocalDir), 0.0);
        
        // half3 shadow = RgbToLinear(texShadowFinal[uv]);
        float viewDist = length(viewPos);
        float geo_NoLm = 1.0 - max(dot(normal.geo, scene[0].SkyLightLocalDir), 0.0);
        float normal_bias = geo_NoLm * (viewDist * 0.006 + 0.06);
        float offset_bias = viewDist * 0.002;

        float3 shadowLocalPos = normal.geo * normal_bias + localPos;
        float3 shadowViewPos = mul3(ap.celestial.view, shadowLocalPos);
        shadowViewPos.z += offset_bias;
        
        int cascade = GetShadowProjection(shadowViewPos, 0.02);

        half shadow = (half)1.0;
        if (cascade >= 0) {
            float3 shadowPos = mul3(ap.celestial.projection[cascade], shadowViewPos) * 0.5 + 0.5;
            shadow = SampleShadow(shadowPos, cascade);
        }

        bool shadowIsSun = dot(ap.celestial.position, ap.celestial.sunPosition) > 0.0;

        CelestialLight sun;
        sun.localDir = GetAreaLightDir(normal.tex, viewLocalDir, scene[0].SunLocalDir, sun_distanceMm, sun_radiusMm);
        half3 sun_color = scene[0].SunColor * sampleSkyTransmit(surface.skyPos, sun.localDir);
        sun.color = sun_color * (shadowIsSun ? shadow : half3(1.0));

        SampleCelestial(output.diffuse, output.specular, sun, surface, viewLocalDir, NoVm);

        CelestialLight moon;
        moon.localDir = GetAreaLightDir(normal.tex, viewLocalDir, scene[0].MoonLocalDir, moon_distanceKm, moon_radiusKm);
        half3 moon_color = scene[0].MoonColor * sampleSkyTransmit(surface.skyPos, moon.localDir);
        moon.color = moon_color * (shadowIsSun ? half3(1.0) : shadow);

        SampleCelestial(output.diffuse, output.specular, moon, surface, viewLocalDir, NoVm);

        half3 sky_ambient = sampleSkyIrradiance(normal.tex) * lmcoord_y * mat_lit.occlusion;
        output.diffuse = output.diffuse / (half)PI + sky_ambient;

        if (ReflectMode == Reflect_SkyOnly) {
            float3 reflectLocalNormal = randomizeNormal(uv, normal.tex, surface.roughL);

            float3 fragViewDir = normalize(viewPos);
            float3 viewNormal = mul(float3x3(ap.camera.view), reflectLocalNormal);
            float3 reflectViewDir = reflect(fragViewDir, viewNormal);
            float3 reflectLocalDir = mul(float3x3(ap.camera.viewInv), reflectViewDir);
            reflectLocalDir = normalize(reflectLocalDir);

            half3 skyColor = sampleSkyView(surface.skyPos, reflectLocalDir, scene[0].SunLocalDir);
            half3 F_NoV = F_schlickRough(NoVm, surface.f0, surface.roughL);
            output.specular += F_NoV * skyColor * (((half)1.0 - surface.roughL) * lmcoord_y);
            // output.diffuse *= half3(1.0) - F_NoV;
        }
    }

    return output;
}
