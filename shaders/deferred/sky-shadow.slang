import aperture;
import buffers.ObjectData;
import lib.common;
import lib.blocks;
import lib.noise.IGN;
import lib.material.pbr;
import lib.light.shadow;
import lib.water.common;

extern static const bool RENDER_TRANSLUCENT = false;

Sampler2D<float> texDepth;

Sampler2D<half4> texAlbedoGB;
Sampler2D<uint2> texNormalGB;
Sampler2D<uint2> texMatLightGB;


struct FragmentOutput {
    half4 shadow : SV_Target0;
    half4 sss : SV_Target1;
};

[[shader("fragment")]]
FragmentOutput skyShadowSss(float2 pos : SV_Position) {
    FragmentOutput output;
    output.shadow = half4(1);
    output.sss = half4(0, 0, 0, 1);

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

        half sss = mat_sss(mat_lit.specular.b);

        float dither = IGN_TAA(pos);

        // Shadows
        float viewDist = length(localPos) + 1.0;
        float geo_NoLm = 1.0 - max(dot(normals.geo, scene[0].SkyLightLocalDir), 0.0);
        float normal_bias = geo_NoLm * saturate(viewDist * 0.004) * (1.0 - sss);
        float offset_bias = saturate(viewDist * 0.002);

        // float3 shadowLocalPos = normals.geo * normal_bias * (1.0 - sss) + localPos;
        float3 shadowLocalPos = normals.geo * normal_bias + localPos;
        float3 shadowViewPos = mul3(ap.celestial.view, shadowLocalPos);
        shadowViewPos.z += offset_bias;// * (1.0 - sss);
        
        int cascade = GetShadowProjection(shadowViewPos, Shadow_MaxRadius);

        if (cascade >= 0) {
            float3 shadowPos = mul3(ap.celestial.projection[cascade], shadowViewPos) * 0.5 + 0.5;

            // output.shadow = SampleShadow_PCSS(shadowPos, cascade, dither);
            output.shadow.rgb = SampleShadowColor_PCSS(shadowPos, cascade, dither);

            // TODO: apply water tint
            float3 shadowCoord = float3(shadowPos.xy, cascade);
            uint customId = texShadowBlock.Sample(shadowCoord);
            // uint customId = texShadowBlock.Load(int4(shadowPos.xy * Shadow_Resolution, 0, cascade));
            if (customId == BLOCK_WATER) {
                // float3 cascadeScale = GetShadowProjectionScale(cascade);
                float depth_scale = -0.5 * ap.celestial.projectionInv[cascade][2].z;

                // float depth_opaque = solidShadowMap.Sample(shadowCoord);
                float depth_translucent = shadowMap.Sample(shadowCoord);
                float water_depth = max(shadowPos.z - depth_translucent, 0.0) * depth_scale;
                output.shadow.rgb *= exp(-water_depth * scene[0].WaterAbsorbColor);
            }
        }

        // SSS
        shadowViewPos = mul3(ap.celestial.view, localPos);
        
        float blockRadius = pow2(sss) * Shadow_SssMaxRadius;
        cascade = GetShadowProjection(shadowViewPos, blockRadius);

        if (cascade >= 0) {
            float3 shadowPos = mul3(ap.celestial.projection[cascade], shadowViewPos) * 0.5 + 0.5;

            float3 cascadeScale = GetShadowProjectionScale(cascade);

            float bias_scale = pow2(sss) * Shadow_SssMaxDist * cascadeScale.z;
            float2 maxPixelRadius = blockRadius * cascadeScale.xy;

            // TODO: PCSS
            // float blockerDistance = ShadowBlockerDistance(shadowPos, cascade, maxPixelRadius, cascadeScale.z, dither);
            float2 pixelRadius = maxPixelRadius;
            // if (blockerDistance > 0.0) pixelRadius *= saturate(blockerDistance / sss);
            // pixelRadius = clamp(pixelRadius, 0.0, maxPixelRadius);

            float3 sss_absorb = normalize(RgbToLinear(1.0 - colorData.rgb) + 0.02);

            float3 sss_shadow = SSS_PCF(shadowPos, cascade, sss_absorb, pixelRadius, bias_scale, sss, dither);

            // float absorb_depth = 1.0 * (coverage_dist.y / cascadeScale.z) + 0.1;
            // float3 lit = coverage_dist.x * exp(-(absorb_depth * sss_color + EPSILON));

            // float3 lit = lerp(sss_shadow, output.shadow.rgb, 0.5*sss);
            float3 lit = max(sss_shadow, output.shadow.rgb);
            // float3 lit = sss_shadow*0.5 + 0.5*output.shadow.rgb;

            // float s = rcp(sss);
            // float z = clamp(coverage_dist.y / cascadeScale.z, 1.0, 10.0);
            // // float3 lit = 0.25*RgbToLinear(colorData.rgb) * (exp(-s*z) + 3.0*exp(-(s*z)/3.0));
            // lit *= (exp(-s*z*sss_absorb) + 3.0*exp(-(s*z*sss_absorb)/3.0));

            // half tex_NoLm = max((half)dot(normals.tex, scene[0].SkyLightLocalDir), (half)0.0);
            output.sss.rgb = (half3)LinearToRgb(lit);
        }
    }

    if (!RENDER_TRANSLUCENT) {
        // DEBUG
        // imgDebug[uint2(pos)] = half4(output.sss.rgb, (half)1.0);
    }

    return output;
}
