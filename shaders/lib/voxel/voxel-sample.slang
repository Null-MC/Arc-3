public module voxel_sample;

import aperture;
import lib.common;
import lib.material.pbr;
import lib.sampling.atlas;
import lib.light.shadow;
import lib.light.floodfill;
import lib.water.wetness;
import lib.sky.common;
import lib.sky.scattering;
import lib.sky.sample_transmit;
import lib.sky.sample_irradiance;
import lib.voxel.voxel_tex;
import lib.voxel.voxel_common;

extern static const bool FloodFill_Enabled;

StructuredBuffer<uint2> voxelTexBuffer;

Sampler2D<half3> blockAtlas;
Sampler2D<half4> blockAtlasS;


float2 GetVoxelTexCoord(const in float3 normal, const in float3 voxelPos) {
    float2 hitCoord;

    if (abs(normal.y) > 0.5)      hitCoord = voxelPos.xz;
    else if (abs(normal.z) > 0.5) hitCoord = voxelPos.xy;
    else                          hitCoord = voxelPos.zy;

    return 1.0 - fract(hitCoord);
}

float3 SampleVoxel(const in float3 localPos, const in float3 normal, const in int3 voxelBufferPos, const in float2 voxelTexCoord, const in half wetness, const in bool isGI = false) {
    half3 albedo = half3(0);
    half roughL = (half)0.85;
    half metalness = (half)0.0;
    half porosity = (half)0.7;
    half emission = (half)0.0;

    if (Voxel_InBufferBounds(voxelBufferPos)) {
        VoxelTex voxel;
        uint voxelIndex = Voxel_GetBufferIndex(voxelBufferPos);
        voxel.unpack(voxelTexBuffer[voxelIndex]);
        
        uint3 atlasSize;
        blockAtlas.GetDimensions(0, atlasSize.x, atlasSize.y, atlasSize.z);

        AtlasBounds atlas;
        atlas.CoordMin = voxel.uv_min / float2(atlasSize.xy);
        atlas.CoordSize = voxel.uv_size / float2(atlasSize.xy);
        float2 uv = atlas.GetAtlasCoord(voxelTexCoord);

        albedo = blockAtlas.Sample(uv).rgb * voxel.tint;
		ApplyInputTransform(albedo);

        half4 specularData = blockAtlasS.Sample(uv);
        half roughness = mat_roughness(specularData.r);
        half f0_metal = mat_f0_metal(specularData.g);
        porosity = mat_porosity(specularData.b, roughness, f0_metal);
        emission = mat_emission(specularData);

        metalness = mat_metalness(f0_metal);
        roughL = pow2(roughness);

        if (voxelTexBuffer[voxelIndex].r == 0) {
            // debug missing data with red albedo
            // albedo = half3(1);//half3(1, 0, 0);
        }
    }

    int3 voxelPos = int3(floor(localPos + 0.04*normal + ap.camera.position));
    float2 lmcoord = saturate(ap.voxel[voxelPos].lightData / 15.0);
    if (!isGI) lmcoord = pow2(lmcoord);

    float3 diffuse = 0.0;

    if (FloodFill_Enabled) {
        float3 lpvPos = FloodFill_GetBufferPosition(localPos);
        lpvPos += normal * 0.5;
        
        if (FloodFill_InBounds(lpvPos)) {
            lmcoord.x = 0.0;
            diffuse += floodfill_sample(lpvPos) * BLOCK_LUX;
        }
    }

    diffuse += lmcoord.x * BLOCK_LUX * BlockLightColor;

    if (World_HasSky) {
        float3 shadowLocalPos = normal * 0.04 + localPos;
        float3 shadowViewPos = mul3(ap.celestial.view, shadowLocalPos);
        shadowViewPos.z += 0.008;

        int shadowCascade = GetShadowProjection(shadowViewPos, 0.0);
        // int shadowCascade = GetShadowProjection_BestFit(shadowViewPos);

        half3 shadow = half3(1.0);
        if (shadowCascade >= 0) {
            float3 shadowPos = mul3(ap.celestial.projection[shadowCascade], shadowViewPos);
            shadow = SampleShadowColor(shadowPos * 0.5 + 0.5, shadowCascade);
        }

        float3 skyPos = getSkyPosition(localPos);
        bool shadowIsSun = dot(ap.celestial.position, ap.celestial.sunPosition) > 0.0;

        half3 sun_color = scene[0].SunColor * sampleSkyTransmit(skyPos, scene[0].SunLocalDir);
        // sun_color *= atmosAbsorb(skyPos, scene[0].SunLocalDir);
        float NoLm_sun = max(dot(normal, scene[0].SunLocalDir), 0.0);
        diffuse += NoLm_sun * (shadowIsSun ? shadow : (half)0.0) * sun_color;

        half3 moon_color = scene[0].MoonColor * sampleSkyTransmit(skyPos, scene[0].MoonLocalDir);
        // moon_color *= atmosAbsorb(skyPos, scene[0].MoonLocalDir);
        float NoLm_moon = max(dot(normal, scene[0].MoonLocalDir), 0.0);
        diffuse += NoLm_moon * (shadowIsSun ? (half)0.0 : shadow) * moon_color;
    }

    if (World_HasSky) {
        diffuse += sampleSkyIrradiance(normal) * lmcoord.y;
    }

    diffuse /= PI;

    // remove diffuse for smooth metals
    half smoothness = (half)1.0 - roughL;
    diffuse *= (half)1.0 - metalness * smoothness;

    // diffuse += emission * BLOCK_LUM;

    if (!isGI) {
        diffuse += emission * BLOCK_LUM;

        if (Debug_WhiteWorld) albedo = WhiteWorldColor;
    }

    albedo = Wetness_GetAlbedo(albedo, porosity, wetness);

    return albedo * diffuse;
}
