import aperture;
import buffers.ObjectData;
import lib.common;
import lib.blocks;
import lib.sampling.IGN;
import lib.sampling.depth;
import lib.water.common;
import lib.sky.sample_final;
import lib.voxel.voxel_tex;
import lib.voxel.voxel_mask;
import lib.voxel.voxel_sample;
import lib.material.pbr;
import lib.material.rough_normal;
import lib.dda;

extern static const int Refract_VoxelStepCount = 32;
extern static const bool Refract_SS_Fallback;
extern static const bool Refract_Rough;

StructuredBuffer<VoxelMask> VoxelMaskBuffer;

Sampler2D<float> mainDepthTex;
Sampler2D<float> solidDepthTex;

Sampler2D<half3> texFinal_opaque;
Sampler2D<half4> texFinal_translucent;
Sampler2D<uint2> texNormalGB_translucent;
Sampler2D<uint2> texMatLightGB_translucent;
Sampler2D<half3> texTintTranslucent;

Sampler2D<half4> texWeather;


[[shader("fragment")]]
float4 applyOverlays(float2 pos : SV_Position) : SV_Target0 {
    uint2 uv = uint2(pos);

    half4 weather = texWeather[uv];
    half4 translucent = texFinal_translucent[uv];
    // uint transData = texDataTranslucent[uv];

    float2 texcoord = pos / ap.game.screenSize;
    if (TAA_Enabled) texcoord += scene[0].taa_jitter;

    float transDepth = mainDepthTex[uv];
    float3 transClipPos = float3(texcoord, transDepth) * 2.0 - 1.0;
    float3 transViewPos = project(ap.camera.projectionInv, transClipPos);
    float3 transLocalPos = mul3(ap.camera.viewInv, transViewPos);
    float transDist = length(transViewPos);

    float3 viewDir = transViewPos / transDist;
    float3 localDir = transLocalPos / transDist;

    half3 opaque_color = texFinal_opaque[uv];
    
    bool hasOverlay = translucent.a > 0.0;
    half3 tint = half3(1.0);

    if (hasOverlay) {
        tint = RgbToLinear(texTintTranslucent[uv]);

        float3 tex_normal = ObjectData_Normals.unpackTex(texNormalGB_translucent[uv].g);

        ObjectData_MatLit mat_lit;
        mat_lit.unpack(texMatLightGB_translucent[uv]);
        half roughness = mat_roughness(mat_lit.specular.r);
        half roughL = pow2(roughness);

        float3 refract_normal = Refract_Rough
            ? randomizeNormal(uv, tex_normal, roughL)
            : tex_normal;

        const float IOR_AIR   = 1.0003;
        const float IOR_WATER   = 1.333;
        const float IOR_DEFAULT = 1.5;
        // TODO: store and use actual translucent IOR
        const float ETA_AIR_TO_WATER = (IOR_AIR/IOR_WATER);
        const float ETA_WATER_TO_AIR = 1.02;// (IOR_WATER/IOR_AIR);
        float eta = ap.camera.fluid == 1 ? ETA_WATER_TO_AIR : ETA_AIR_TO_WATER;

        float3 refract_viewNormal = mul(float3x3(ap.camera.view), refract_normal);
        float3 refract_viewDir = refract(viewDir, refract_viewNormal, eta);
        float3 refract_viewPos = transDist * viewDir;

        int3 hit_voxelMaskPos = -1;

        if (dot(refract_viewDir, refract_viewDir) < EPSILON) {
            opaque_color = half3(0.0);
        }
        else {
            float3 refract_localDir = mul(float3x3(ap.camera.viewInv), refract_viewDir);

            float3 cameraFract = fract(ap.camera.position);
            int3 cameraFloor = int3(floor(ap.camera.position));

            float3 stepSizes, nextDist, stepAxis;
            float3 traceLocalStart = (transDist + EPSILON) * localDir;
            float3 currPos = traceLocalStart + cameraFract;
            DDA_init(stepSizes, nextDist, currPos, refract_localDir);

            float traceWaterDist = 0.0;
            bool hit = false;

            for (uint i = 0; i < Refract_VoxelStepCount; i++) {
                float3 stepAxisNext;
                float3 step = DDA_step(stepAxisNext, nextDist, stepSizes, refract_localDir);

                hit_voxelMaskPos = int3(floor(VoxelMask_GetBufferPosition(currPos + 0.5*step - cameraFract)));
                uint voxelIndex = VoxelMask_GetBufferIndex(hit_voxelMaskPos);
                var voxelMask = VoxelMaskBuffer[voxelIndex];
                uint maskId = voxelMask.getId();

                if (maskId == MaskId_Solid) {
                    hit = true;
                    break;
                }
                else if (maskId == MaskId_Water) {
                    traceWaterDist += length(step);
                }

                currPos += step;
                stepAxis = stepAxisNext;
            }

            float3 hit_localPos = currPos - cameraFract;
            opaque_color = half3(0.65);

            bool ss_hit = false;
            if (Refract_SS_Fallback) {
                float dither = InterleavedGradientNoiseTime(pos);

                float3 traceViewStart = mul3(ap.camera.view, traceLocalStart);
                float3 traceClipStart = project(ap.camera.projection, traceViewStart);

                float3 traceViewEnd = mul3(ap.camera.view, hit_localPos);
                float3 traceClipEnd = project(ap.camera.projection, traceViewEnd);

                const uint SS_StepCount = 24;
                const uint SS_RefineSteps = 8;

                float3 traceClipPos;
                float3 traceClipPos_prev = traceClipStart;
                float2 traceScreenPos;
                float traceDepthL_prev = linearizeDepth(traceClipStart.z, ap.camera.near, ap.camera.far);
                for (uint i = 0; i < SS_StepCount; i++) {
                    float f = (i + dither) / SS_StepCount;
                    traceClipPos = lerp(traceClipStart, traceClipEnd, f);
                    traceScreenPos = traceClipPos.xy * 0.5 + 0.5;
                    if (!all(saturate(traceScreenPos) == traceScreenPos)) break;

                    float sampleClipDepth = solidDepthTex.Sample(traceScreenPos) * 2.0 - 1.0;
                    float screenDepthL = linearizeDepth(sampleClipDepth, ap.camera.near, ap.camera.far);
                    float traceDepthL = linearizeDepth(traceClipPos.z, ap.camera.near, ap.camera.far);

                    float stepMaxZ = abs(traceDepthL - traceDepthL_prev);

                    if (abs(screenDepthL - traceDepthL) < stepMaxZ) {
                        hit = true;
                        ss_hit = true;
                        break;
                    }

                    traceClipPos_prev = traceClipPos;
                    traceDepthL_prev = traceDepthL;
                }

                if (ss_hit) {
                    traceClipStart = traceClipPos_prev;
                    traceClipEnd = traceClipPos;

                    traceDepthL_prev = linearizeDepth(traceClipStart.z, ap.camera.near, ap.camera.far);
                    for (uint i = 0; i < SS_RefineSteps; i++) {
                        float f = (i + dither) / SS_RefineSteps;
                        traceClipPos = lerp(traceClipStart, traceClipEnd, f);
                        traceScreenPos = traceClipPos.xy * 0.5 + 0.5;
                        if (!all(saturate(traceScreenPos) == traceScreenPos)) break;

                        float sampleClipDepth = solidDepthTex.Sample(traceScreenPos) * 2.0 - 1.0;
                        float screenDepthL = linearizeDepth(sampleClipDepth, ap.camera.near, ap.camera.far);
                        float traceDepthL = linearizeDepth(traceClipPos.z, ap.camera.near, ap.camera.far);

                        float stepMaxZ = abs(traceDepthL - traceDepthL_prev);

                        if (abs(screenDepthL - traceDepthL) < stepMaxZ) {
                            break;
                        }
                    }
                }

                if (ss_hit) {
                    opaque_color = texFinal_opaque.Sample(traceScreenPos);

                    // TODO: check if pixel is water, and recalc new hit point distance
                    traceWaterDist = 0.0;
                }
            }

            if (!ss_hit) {
                // recreate final sample
                if (hit) {
                    float3 hit_normal = -stepAxis * sign(refract_localDir);

                    // TODO: these line up for now, but need a proper conversion!
                    int3 hit_voxelTexPos = hit_voxelMaskPos;

                    float2 voxelTexCoord = GetVoxelTexCoord(hit_normal, currPos);
                    opaque_color = SampleVoxel(hit_localPos, hit_normal, hit_voxelTexPos, voxelTexCoord);
                }
                else {
                    opaque_color = sampleSkyFinal(hit_localPos, refract_localDir, false);
                }
            }

            if (traceWaterDist > 0.0)
                opaque_color *= half3(exp(-traceWaterDist * Water_AbsorbColor));
        }
    }

    half3 final_color = opaque_color;

    if (hasOverlay) {
        final_color *= tint;

        final_color = fma(final_color, half3(1.0 - translucent.a), translucent.rgb);
    }

    if (ap.camera.fluid == 1) {
        half3 opaqueWaterTint = half3(exp(-(transDist + EPSILON) * Water_AbsorbColor));
        final_color *= opaqueWaterTint;
    }
    
    final_color.rgb += weather.rgb * half3(0.25);

    return half4(final_color, half2(1.0).x);
}
