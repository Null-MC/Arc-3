import aperture;
import lib.common;
import lib.light.fresnel;
import lib.light.floodfill;
import lib.light.hand;
import lib.light.brdf;
import lib.sky.common;
import lib.sky.sun;
import lib.sky.moon;
import lib.sky.sample_transmit;
import lib.sky.sample_irradiance;
import lib.sky.sample_view;
import lib.sky.sample_light;
import lib.water.waves;
import lib.water.water_depth;
import lib.sampling.dfd_normal;
import lib.shadow;
import lib.material.pbr;
import lib.material.parallax;
import lib.tbn;

// extern static const float BLOCK_LUX;
extern static const bool RENDER_TERRAIN = false;
extern static const bool RENDER_PARTICLES = false;
extern static const bool Water_WaveEnabled = false;
extern static const bool FloodFill_Enabled;
extern static const bool Debug_WhiteWorld;
extern static const int ReflectMode;

extern static const uint BLOCK_WATER;

static const bool SupportsParallax = Parallax_Enabled && !RENDER_PARTICLES;
static const bool SupportsTexNormals = !RENDER_PARTICLES;


uint GetWaveOctaveCount(const in float viewDist) {
    float value = lerp(settings.Water_WaveDetail, 6.0, saturate(viewDist / 80.0));
    return clamp(int(value), 1, 32);
}


struct VertexOutput {
    float4 position : SV_Position;

    float4 color;
    float2 uv;
    float2 light;
    float3 normal;
    float occlusion;
    float4 tangent;
    float3 viewPos;
    float waveStrength;
    float waveOffset;
    float3 localPos;
    nointerpolation uint blockId;
};

[[shader("vertex")]]
VertexOutput vertexMain(Vertex input) {
    VertexOutput output;
    output.uv = input.uv();
    output.color = input.color();
    output.light = input.light();

    float3 modelPos = input.pos().xyz;
    output.viewPos = mul3(input.viewMatrix(), modelPos);
    output.localPos = mul3(ap.camera.viewInv, output.viewPos);

    output.occlusion = 1.0;
    if (RENDER_TERRAIN) {
        output.occlusion = input.ao();
    }

    output.normal = 0.0;//mul(float3x3(ap.camera.viewInv), float3(0,0,1));
    if (let normal = input.normal()) {
        output.normal = mul(input.normalMatrix(), normal);
        output.normal = mul(float3x3(ap.camera.viewInv), output.normal);
    }

    bool isWater = false;
    output.blockId = -1;
    output.waveStrength = 0.0;
    output.waveOffset = 0.0;
    // uint blockMapId = 0u;
    if (let value = input.blockId()) {
        output.blockId = value;

        if (Water_WaveEnabled) {
            uint blockMapId = ap.blocks[output.blockId].customId;
            float3 worldPos = output.localPos + input.midBlock().value/64.0 + ap.camera.position;
            bool isFacingAir = ap.voxel[int3(floor(worldPos + output.normal))].blockId == 0;
            isWater = blockMapId == BLOCK_WATER;

            if (isWater) {
                output.waveStrength = 1.0;

                float viewDist = length(output.viewPos);
                int octaves = GetWaveOctaveCount(viewDist);
                output.waveOffset = GetWaveHeight(ap.camera.position + output.localPos, output.light.y, ap.timing.timeElapsed, octaves).y;
                output.localPos.y += output.waveOffset;
            }
        }
    }

    //output.tangent = 0.0;
    if (SupportsTexNormals) {
        output.tangent = 0.0;
        if (let value = input.tangent()) {
            output.tangent.xyz = mul(input.normalMatrix(), value.xyz);
            output.tangent.xyz = mul(float3x3(ap.camera.viewInv), output.tangent.xyz);
            output.tangent.xyz = normalize(output.tangent.xyz);
            output.tangent.w = value.w;
        }
    }

    if (let overlayColor = input.overlayColor()) {
        output.color = lerp(output.color, overlayColor, overlayColor.a);
    }

    output.viewPos = mul3(ap.camera.view, output.localPos);
    output.position = mul(ap.camera.projection, float4(output.viewPos, 1.0));

    if (TAA_Enabled) {
        output.position.xy += scene[0].taa_jitter * (2.0 * output.position.w);
    }

    // if (isWater) {
    //     output.normal
    // }

    return output;
}


struct FragmentOutput {
    float4 color : SV_Target0;
    float4 tint : SV_Target1;
    uint data : SV_Target2;
    //float2 velocity : SV_Target2;
};

[[shader("fragment")]]
FragmentOutput fragmentMain(VertexOutput input, float2 fragPos : SV_Position) {
    FragmentOutput output;
    //output.velocity = 0.0;
    output.tint = 1.0;

    float LOD = albedoTex.CalculateLevelOfDetail(input.uv);
    float4 albedo = albedoTex.SampleLevel(input.uv, LOD) * input.color;
    iris_discardIfNeeded(albedo);

    if (RENDER_PARTICLES) {
        // HACK: aperture discard doesn't include particles
        if (albedo.a < (0.5/255.0)) discard;
    }

    albedo.rgb = RgbToLinear(albedo.rgb);
    if (Debug_WhiteWorld) albedo.rgb = 0.85;

    float4 normalData = normalTex.SampleLevel(input.uv, LOD);
    float4 specularData = specularTex.SampleLevel(input.uv, LOD);

    bool has_normal = true;
    float3 geo_normal = 0.0;
    if (dot(input.normal, input.normal) > EPSILON)
        geo_normal = normalize(input.normal);
    else has_normal = false;

    float viewDist = length(input.localPos);

    uint blockMapId = ap.blocks[input.blockId].customId;
    bool isWater = blockMapId == BLOCK_WATER;

    // if (isWater) {
    //     WaterDepth_set(uint2(fragPos), viewDist);
    //     discard;
    // }

    float3 tex_normal = geo_normal;
    if (SupportsTexNormals) {
        if (Water_WaveEnabled && isWater && input.waveStrength > 0.5) {
            float3 offsetLocalPos = input.localPos;
            offsetLocalPos.y -= input.waveOffset;

            int octaves = GetWaveOctaveCount(viewDist);
            float3 waveOffset = GetWaveHeight(ap.camera.position + offsetLocalPos, input.light.y, ap.timing.timeElapsed, octaves);

            tex_normal = getSurfaceNormal((waveOffset + offsetLocalPos), float3(0,1,0));
            // albedo = float4(tex_normal * 0.5 + 0.5, 1.0);
        }
        else {
            tex_normal = mat_normal(normalData.rgb);

            float3 tangent = normalize(input.tangent.xyz);
            float3x3 TBN = GetTBN(geo_normal, tangent, input.tangent.w);

            tex_normal = normalize(mul(tex_normal, TBN));
        }
    }

    float roughness = mat_roughness(specularData.r);
    float f0_metal = mat_f0_metal(specularData.g);

    float2 lmcoord = input.light.rg*input.light.rg;

    float tex_ao = mat_occlusion(normalData.b);
    float occlusion = tex_ao * input.occlusion;

    float3 viewLocalDir = -normalize(input.localPos);

    float geo_NoLm = 1.0;
    if (has_normal) geo_NoLm = 1.0 - abs(dot(geo_normal, scene[0].SkyLightLocalDir));

    // float viewDist = length(input.localPos);
    float normal_bias = geo_NoLm * (viewDist * 0.006 + 0.06);
    float offset_bias = viewDist * 0.002;

    float3 shadowLocalPos = geo_normal * normal_bias + input.localPos;
    float3 shadowViewPos = mul3(ap.celestial.view, shadowLocalPos);
    shadowViewPos.z += offset_bias;

    const float paddingBlocks = 0.05;
    int shadowCascade = GetShadowProjection(shadowViewPos, paddingBlocks);

    float shadow = 1.0;
    if (shadowCascade >= 0) {
        float3 shadowPos = mul3(ap.celestial.projection[shadowCascade], shadowViewPos).xyz * 0.5 + 0.5;
        shadow = SampleShadow(shadowPos, shadowCascade);
    }

    float metalness = mat_metalness(f0_metal);

    if (isWater) {
        albedo = float4(0.0, 0.0, 0.0, 0.02);
        roughness = 0.04;
        f0_metal = 0.02;
    }
    else {
        float3 tint = lerp(1.0, albedo.rgb, pow2(albedo.a));
        output.tint = float4(tint, 1.0);
    }

    SurfaceData surface;
    surface.skyPos = getSkyPosition(input.localPos);
    surface.normal = tex_normal;
    surface.roughL = roughness*roughness;
    surface.f0 = lerp(f0_metal, albedo.rgb, metalness);
    surface.tint = lerp(1.0, albedo.rgb, metalness);

    CelestialLight sun;
    sun.localDir = GetAreaLightDir(tex_normal, viewLocalDir, scene[0].SunLocalDir, sun_distanceMm, sun_radiusMm);
    sun.color = scene[0].SunColor * sampleSkyTransmit(surface.skyPos, sun.localDir);

    CelestialLight moon;
    moon.localDir = GetAreaLightDir(tex_normal, viewLocalDir, scene[0].MoonLocalDir, moon_distanceKm, moon_radiusKm);
    moon.color = scene[0].MoonColor * sampleSkyTransmit(surface.skyPos, moon.localDir);

    // float3 sss_ambient = sampleSkyIrradiance(-tex_normal) * lmcoord_y;
    //float3 sssFinal = texSssFinal[uv] * (sun.color + moon.color) + sss_ambient * sss;
    // diffuse += sssFinal / PI;

    bool shadowIsSun = dot(ap.celestial.position, ap.celestial.sunPosition) > 0.0;
    float NoVm = max(dot(tex_normal, viewLocalDir), 0.0);
    float3 diffuse = 0.0, specular = 0.0;

    sun.color *= shadowIsSun ? shadow : 1.0;
    SampleCelestial(diffuse, specular, sun, surface, viewLocalDir, NoVm);

    moon.color *= shadowIsSun ? 1.0 : shadow;
    SampleCelestial(diffuse, specular, moon, surface, viewLocalDir, NoVm);

    // FloodFill
    if (FloodFill_Enabled) {
        float3 lpvPos = FloodFill_GetBufferPosition(input.localPos);
        lpvPos -= geo_normal * 0.25;
        lpvPos += tex_normal * 0.75;
        
        if (FloodFill_InBounds(lpvPos)) {
            diffuse += floodfill_sample(lpvPos) * BLOCK_LUX;
            lmcoord.x = 0.0;
        }
    }

    diffuse += lmcoord.x * BLOCK_LUX;

    // Hand Held
    float3 handSampleLocalPos = geo_normal*0.02 + input.localPos;

    if (ap.game.mainHand != 0u) {
        float3 lightLocalPos = GetHandLightPos(HandLightOffset_main);
        GetHandLight(diffuse, specular, ap.game.mainHand, lightLocalPos, handSampleLocalPos, viewLocalDir, tex_normal, geo_normal, surface.f0, surface.roughL);
    }

    if (ap.game.offHand != 0u) {
        float3 lightLocalPos = GetHandLightPos(HandLightOffset_alt);
        GetHandLight(diffuse, specular, ap.game.offHand, lightLocalPos, handSampleLocalPos, viewLocalDir, tex_normal, geo_normal, surface.f0, surface.roughL);
    }

    float3 sky_ambient = sampleSkyIrradiance(tex_normal) * lmcoord.y * occlusion;

    diffuse = diffuse / PI + sky_ambient;

    if (mat_isMetal(f0_metal)) diffuse *= roughness;

    if (ReflectMode == Reflect_SkyOnly) {
        float3 fragViewDir = normalize(input.viewPos);
        float3 viewNormal = mul(float3x3(ap.camera.view), tex_normal);
        float3 reflectViewDir = reflect(fragViewDir, viewNormal);
        float3 reflectLocalDir = mul(float3x3(ap.camera.viewInv), reflectViewDir);
        reflectLocalDir = normalize(reflectLocalDir);

        float3 skyColor = sampleSkyView(surface.skyPos, reflectLocalDir, scene[0].SunLocalDir);
        float3 F_NoV = F_schlickRough(NoVm, surface.f0, surface.roughL);
        specular += F_NoV * skyColor * ((1.0 - roughness) * lmcoord.y);
        diffuse *= 1.0 - F_NoV;

        float F = F_schlickRough(NoVm, f0_metal, surface.roughL);
        albedo.a = (1.0 - F) * albedo.a + F;
    }

    specular *= surface.tint;
    
    const float3 ambient = 0.02;
    float emission = mat_emission(specularData) * BLOCK_LUX;

    output.color.rgb = albedo.rgb * (diffuse + emission + ambient) * albedo.a + specular;
    output.color.a = albedo.a;

    // premultiply alpha
    //output.color.rgb *= output.color.a;

    // clamp to avoid buffer overflow
    output.color = clamp(output.color, 0.0, 65000.0);

    // Refraction
    float3 refractSurfaceNormal = tex_normal - geo_normal;
    // if (MATERIAL_ROUGH_REFRACT) {
    //     randomize_reflection(refractSurfaceNormal, localGeoNormal, roughness);
    // }

    refractSurfaceNormal = normalize(refractSurfaceNormal + 0.2 * geo_normal);
    output.data = packUnorm4x8(float4(tex_normal * 0.5 + 0.5, 1.0));
    output.data = bitfieldInsert(output.data, blockMapId, 24, 8);
    
    return output;
}
