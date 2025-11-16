import aperture;
import buffers.ObjectData;
import lib.common;
import lib.material.pbr;
import lib.sampling.IGN;
import lib.shadow;

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
        float2 texcoord = pos / ap.game.screenSize;
        if (TAA_Enabled) texcoord -= scene[0].taa_jitter;

        float3 clipPos = float3(texcoord, depth) * 2.0 - 1.0;
        float3 viewPos = project(ap.camera.projectionInv, clipPos);
        float3 localPos = mul3(ap.camera.viewInv, viewPos);
        float3 viewLocalDir = -normalize(localPos);

        ObjectData_Normals normals;
        normals.unpack(texNormalGB[uv]);

        ObjectData_MatLit mat_lit;
        mat_lit.unpackSpecular(texMatLightGB[uv].r);

        half sss = mat_sss(mat_lit.specular.b);

        float dither;
        if (TAA_Enabled) {
            dither = InterleavedGradientNoiseTime(uv);
        }
        else {
            dither = InterleavedGradientNoise(uv);
        }

        // Shadows
        float viewDist = length(viewPos);
        float geo_NoLm = 1.0 - max(dot(normals.geo, scene[0].SkyLightLocalDir), 0.0);
        float normal_bias = geo_NoLm * (viewDist * 0.006 + 0.06);
        float offset_bias = viewDist * 0.002;

        float3 shadowLocalPos = normals.geo * normal_bias * (1.0 - sss) + localPos;
        float3 shadowViewPos = mul3(ap.celestial.view, shadowLocalPos);
        shadowViewPos.z += offset_bias * (1.0 - sss);
        
        int cascade = GetShadowProjection(shadowViewPos, Shadow_MaxRadius);

        if (cascade >= 0) {
            float3 shadowPos = mul3(ap.celestial.projection[cascade], shadowViewPos) * 0.5 + 0.5;

            // output.shadow = SampleShadow_PCSS(shadowPos, cascade, dither);
            output.shadow.rgb = SampleShadowColor_PCSS(shadowPos, cascade, dither);
        }

        // SSS
        shadowViewPos = mul3(ap.celestial.view, localPos);
        
        float blockRadius = sss * Shadow_SssMaxRadius;
        cascade = GetShadowProjection(shadowViewPos, blockRadius);

        if (cascade >= 0) {
            float3 shadowPos = mul3(ap.celestial.projection[cascade], shadowViewPos) * 0.5 + 0.5;

            float3 cascadeScale = GetShadowProjectionScale(cascade);

            float bias_scale = sss * Shadow_SssMaxDist * cascadeScale.z;
            float2 pixelRadius = blockRadius * cascadeScale.xy;
            float2 coverage_dist = SSS_PCF(shadowPos, cascade, pixelRadius, bias_scale, sss, dither);

            float absorb_depth = 1.0 * (coverage_dist.y / cascadeScale.z) + 0.1;
            half3 sss_color = normalize(RgbToLinear(1.0 - colorData.rgb) + 0.02);
            half3 lit = coverage_dist.x * exp(-(absorb_depth * sss_color + EPSILON));

            // half tex_NoLm = max((half)dot(normals.tex, scene[0].SkyLightLocalDir), (half)0.0);
            output.sss.rgb = LinearToRgb(sss * lit);
        }
    }

    return output;
}
