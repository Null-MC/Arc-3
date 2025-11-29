import aperture;
import buffers.ObjectData;
import lib.common;
import lib.blocks;
import lib.material.pbr;
import lib.material.rough_normal;
import lib.light.fresnel;
import lib.sampling.depth;
import lib.noise.IGN;
import lib.sky.sample_final;
import lib.water.common;
import lib.water.wetness;
import lib.voxel.voxel_common;
import lib.voxel.voxel_tex;
import lib.voxel.voxel_mask;
import lib.voxel.voxel_sample;
import lib.voxel.dda;
import lib.screen_trace;

extern static const int Reflect_SampleCount = 2;
extern static const bool Reflect_Rough;
extern static const bool Reflect_SS_Fallback;
extern static const int Reflect_VoxelSteps;
extern static const int Reflect_ScreenSteps;
extern static const int Reflect_RefineSteps;
extern static const int BufferWidth;
extern static const int BufferHeight;
extern static const int BufferScale;

static const int2 BufferSize = int2(BufferWidth, BufferHeight);

StructuredBuffer<VoxelMask> VoxelMaskBuffer;

Sampler2D<half3> texSource;
Sampler2D<float> solidDepthTex;
Sampler2D<half2> texWetnessGB;

Sampler2D<half4> texAlbedoGB;
Sampler2D<uint2> texNormalGB;
Sampler2D<uint2> texMatLightGB;


[[shader("fragment")]]
half4 applyReflections(float2 pos : SV_Position) : SV_Target0 {
    uint2 uv_full = uint2(pos) * BufferScale;
    float depth = solidDepthTex[uv_full];
    half3 finalColor = half3(0.0);
    
    if (depth < 1.0) {
        float2 texcoord = (uv_full + 0.5) / ap.game.screenSize;
        if (TAA_Enabled) {
            texcoord -= scene[0].taa_jitter;
            // texcoord += scene[0].taa_jitter * BufferScale;
        }

        float3 screenPos = float3(texcoord, depth);
        float3 clipPos = screenPos * 2.0 - 1.0;
        float3 viewPos = project(ap.camera.projectionInv, clipPos);
        float3 localPos = mul3(ap.camera.viewInv, viewPos);

        half4 colorData = texAlbedoGB[uv_full];

        ObjectData_Normals normals;
        normals.unpack(texNormalGB[uv_full]);

        ObjectData_MatLit mat_lit;
        mat_lit.unpack(texMatLightGB[uv_full]);

        half3 albedo = RgbToLinear(colorData.rgb);
        half roughness = mat_roughness(mat_lit.specular.r);
        half f0_metal = mat_f0_metal(mat_lit.specular.g);
        half metalness = (half)mat_metalness(f0_metal);

        // TODO: wetness
        half2 wetness_puddle = texWetnessGB[uv_full];
        Wetness_ApplyRoughness(roughness, wetness_puddle.x);
        Wetness_ApplyNormal(normals.tex, normals.geo, wetness_puddle.y);
        // f0_metal = (half)lerp(f0_metal, 0.02, wetness);

        half3 f0 = lerp(half3(f0_metal), albedo.rgb, metalness);
        half lmcoord_y = pow2(mat_lit.lmcoord.y);
        half roughL = pow2(roughness);
        
        float viewDist = length(viewPos);
        float3 viewDir = viewPos / viewDist;

        float dither = IGN_TAA(pos);

        [ForceUnroll]
        for (int sample_i = 0; sample_i < Reflect_SampleCount; sample_i++) {
        float3 reflectNormal = Reflect_Rough
            ? randomizeNormal(int2(pos + float2(13, 5)*sample_i), normals.tex, roughL)
            : normals.tex;

        float3 reflect_viewNormal = mul(float3x3(ap.camera.view), reflectNormal);
        float3 reflect_viewDir = reflect(viewDir, reflect_viewNormal);
        half3 reflectColor = half3(0.65);

        bool ss_hit = false;
        if (Reflect_SS_Fallback) {
            float3 screenEnd = projectScreenTrace(viewPos, screenPos, reflect_viewDir);
            float3 traceClipEnd = screenEnd * 2.0 - 1.0;
            float3 traceClipStart = clipPos;

            float3 traceClipPos;
            float3 traceClipPos_prev = traceClipStart;
            float2 traceScreenPos;

            float traceDepthL_prev = linearizeDepth(traceClipStart.z, ap.camera.near, ap.camera.far);
            for (uint i = 1; i < Reflect_ScreenSteps; i++) {
                float f = (i + dither) / Reflect_ScreenSteps;
                traceClipPos = lerp(traceClipStart, traceClipEnd, f);
                traceScreenPos = traceClipPos.xy * 0.5 + 0.5;
                if (!all(saturate(traceScreenPos) == traceScreenPos)) break;

                float sampleClipDepth = solidDepthTex.Sample(traceScreenPos) * 2.0 - 1.0;
                float screenDepthL = linearizeDepth(sampleClipDepth, ap.camera.near, ap.camera.far);
                float traceDepthL = linearizeDepth(traceClipPos.z, ap.camera.near, ap.camera.far);

                float stepMaxZ = abs(traceDepthL - traceDepthL_prev);

                if (abs(screenDepthL - traceDepthL) < stepMaxZ) {
                    ss_hit = true;
                    break;
                }

                traceClipPos_prev = traceClipPos;
                traceDepthL_prev = traceDepthL;
            }

            if (ss_hit) {
                traceClipStart = traceClipPos_prev;
                traceClipEnd = traceClipPos;

                for (uint i = 0; i < Reflect_RefineSteps; i++) {
                    float f = (i + dither) / Reflect_RefineSteps;
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

            if (ss_hit) reflectColor = texSource.Sample(traceScreenPos);
        }

        float3 localDir = normalize(localPos);

        if (!ss_hit) {
            float3 reflect_localDir = mul(float3x3(ap.camera.viewInv), reflect_viewDir);

            float3 cameraFract = fract(ap.camera.position);
            int3 cameraFloor = int3(floor(ap.camera.position));

            float3 stepSizes, nextDist, stepAxis;
            float3 currPos = localPos + cameraFract - localDir*0.02;
            DDA_init(stepSizes, nextDist, currPos, reflect_localDir);

            float traceWaterDist = 0.0;
            int3 hit_voxelMaskPos = -1;
            bool isLastBlockWater = ap.camera.fluid == 1;
            bool hit = false;

            if (ap.camera.fluid == 1) traceWaterDist += viewDist;

            for (uint i = 0; i < Reflect_VoxelSteps; i++) {
                float3 stepAxisNext;
                float3 step = DDA_step(stepAxisNext, nextDist, stepSizes, reflect_localDir);

                hit_voxelMaskPos = int3(floor(Voxel_GetBufferPosition(currPos + 0.5*step - cameraFract)));
                uint voxelIndex = Voxel_GetBufferIndex(hit_voxelMaskPos);
                var voxelMask = VoxelMaskBuffer[voxelIndex];
                uint maskId = voxelMask.getId();

                bool isWater = maskId == MaskId_Water;

                if (isWater) {
                    traceWaterDist += length(step);
                }
                else if (maskId != MaskId_Empty) {
                    hit = true;
                    break;
                }

                currPos += step;
                stepAxis = stepAxisNext;
                isLastBlockWater = isWater;
            }

            float3 hit_localPos = currPos - cameraFract;

            // recreate final sample
            if (hit) {
                float3 hit_normal = -stepAxis * sign(reflect_localDir);
                half wetness = (half)isLastBlockWater;

                // TODO: these line up for now, but need a proper conversion!
                int3 hit_voxelTexPos = hit_voxelMaskPos;

                float2 voxelTexCoord = GetVoxelTexCoord(hit_normal, currPos);
                reflectColor = SampleVoxel(hit_localPos, hit_normal, hit_voxelTexPos, voxelTexCoord, wetness);
            }
            else {
                reflectColor = sampleSkyFinal(hit_localPos, reflect_localDir, false);
                reflectColor *= lmcoord_y;
            }

            if (traceWaterDist > 0.0)
                reflectColor *= half3(exp(-traceWaterDist * Water_AbsorbColor));
        }

        half NoVm = max(dot(reflectNormal, -localDir), (half)0.0);
        half3 F_NoV = F_Lazanyi2019(NoVm, f0);

        half3 specular_tint = lerp((half)1.0, albedo, metalness);

        // imgDebug[uv] = float4(LinearToRgb(reflectColor * 0.008), 1.0);

        finalColor += F_NoV * reflectColor * specular_tint;
        // finalColor = reflectColor * specular_tint;
        }
    }

    return half4(finalColor / Reflect_SampleCount, (half)1.0);
}
