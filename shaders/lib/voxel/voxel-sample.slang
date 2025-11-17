public module voxel_sample;

import aperture;
import lib.common;
import lib.shadow;
import lib.material.pbr;
import lib.sampling.atlas;
import lib.voxel.voxel_tex;
import lib.sky.common;
import lib.sky.sample_transmit;
import lib.sky.sample_irradiance;

extern static const bool World_HasSky;
extern static const half BLOCK_LUX;

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

float3 SampleVoxel(const in float3 localPos, const in float3 normal, const in int3 voxelTexPos, const in float2 voxelTexCoord, bool skyLight = true) {
    float3 albedo = 0.0;
    half roughL = (half)0.85;
    half metalness = (half)0.0;
    half emission = (half)0.0;
    if (VoxelTex_InBounds(voxelTexPos)) {
        VoxelTex voxel;
        uint voxelIndex = VoxelTex_GetBufferIndex(voxelTexPos);
        voxel.unpack(voxelTexBuffer[voxelIndex]);
        
        uint3 atlasSize;
        blockAtlas.GetDimensions(0, atlasSize.x, atlasSize.y, atlasSize.z);

        AtlasBounds atlas;
        atlas.CoordMin = voxel.uv_min / float2(atlasSize.xy);
        atlas.CoordSize = voxel.uv_size / float2(atlasSize.xy);
        float2 uv = atlas.GetAtlasCoord(voxelTexCoord);

        albedo = blockAtlas.Sample(uv).rgb * voxel.tint;
        albedo = RgbToLinear(albedo);

        half4 specularData = blockAtlasS.Sample(uv);
        half roughness = mat_roughness(specularData.r);
        metalness = mat_metalness(specularData.g);
        emission = mat_emission(specularData);
        roughL = pow2(roughness);

        if (voxelTexBuffer[voxelIndex].r == 0) {
            // debug missing data with red albedo
            albedo = half3(0.0);//half3(1, 0, 0);
        }
    }

    half3 diffuse = half3(0.0);

    if (World_HasSky) {
        float3 shadowLocalPos = normal * 0.04 + localPos;
        float3 shadowViewPos = mul3(ap.celestial.view, shadowLocalPos);
        shadowViewPos.z += 0.008;

        int shadowCascade = GetShadowProjection(shadowViewPos, 0.05);

        half3 shadow = half3(1.0);
        if (shadowCascade >= 0) {
            float3 shadowPos = mul3(ap.celestial.projection[shadowCascade], shadowViewPos);
            shadow = SampleShadowColor(shadowPos * 0.5 + 0.5, shadowCascade);
        }

        float3 skyPos = getSkyPosition(localPos);
        bool shadowIsSun = dot(ap.celestial.position, ap.celestial.sunPosition) > 0.0;

        // TODO: separate sun/moon shadow

        float NoLm_sun = max(dot(normal, scene[0].SunLocalDir), 0.0);
        half3 sunTransmit = sampleSkyTransmit(skyPos, scene[0].SunLocalDir);
        diffuse += NoLm_sun * (shadowIsSun ? shadow : (half)1.0) * sunTransmit * scene[0].SunColor;

        float NoLm_moon = max(dot(normal, scene[0].MoonLocalDir), 0.0);
        half3 moonTransmit = sampleSkyTransmit(skyPos, scene[0].MoonLocalDir);
        diffuse += NoLm_moon * (shadowIsSun ? (half)1.0 : shadow) * moonTransmit * scene[0].MoonColor;

        diffuse /= PI;

        if (skyLight) {
            // TODO: recalc from local-pos + normal offset
            int3 voxelPos = int3(floor(localPos + 0.04*normal + ap.camera.position));
            float lmcoord_y = saturate(ap.voxel[voxelPos].lightData.y / 15.0);
            diffuse += sampleSkyIrradiance(normal) * lmcoord_y;
        }
    }

    // remove diffuse for smooth metals
    half smoothness = (half)1.0 - roughL;
    diffuse *= (half)1.0 - metalness * smoothness;

    diffuse += emission * BLOCK_LUX;

    if (Debug_WhiteWorld) albedo = WhiteWorldColor;

    return albedo * diffuse;
}
