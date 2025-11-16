import aperture;
import buffers.ObjectData;
import lib.common;
import lib.blocks;
import lib.material.pbr;
import lib.material.rough_normal;
import lib.light.fresnel;
import lib.sampling.depth;
import lib.sampling.IGN;
import lib.sampling.R2;
import lib.sky.common;
import lib.sky.sample_view;
import lib.water.common;
import lib.voxel.voxel_tex;
import lib.voxel.voxel_mask;
import lib.voxel.voxel_sample;
import lib.dda;

extern static const int GI_VoxelStepCount;
extern static const bool GI_ScreenTrace;

static const int GI_ScreenStepCount = 12;
static const int GI_ScreenRefineCount = 4;

StructuredBuffer<VoxelMask> VoxelMaskBuffer;

Sampler2D<float> solidDepthTex;
Sampler2D<half3> texDiffuse;

Sampler2D<half4> texAlbedoGB;
Sampler2D<uint2> texNormalGB;
Sampler2D<uint2> texMatLightGB;


[[shader("fragment")]]
half4 applyGI(float2 pos : SV_Position) : SV_Target0 {
    uint2 uv = uint2(pos);
    float depth = solidDepthTex[uv];
    half3 diffuse = half3(0.0);
    
    if (depth < 1.0) {
        float2 texcoord = pos / ap.game.screenSize;
        if (TAA_Enabled) texcoord -= scene[0].taa_jitter;

        float3 clipPos = float3(texcoord, depth) * 2.0 - 1.0;
        float3 viewPos = project(ap.camera.projectionInv, clipPos);
        float3 localPos = mul3(ap.camera.viewInv, viewPos);

        float3 localDir = normalize(localPos);
        float3 offsetLocalPos = localPos - localDir*0.02;

        half3 tex_normal = ObjectData_Normals.unpackTex(texNormalGB[uv].g);

        ObjectData_MatLit mat_lit;
        mat_lit.unpack(texMatLightGB[uv]);

        half lmcoord_y = pow2(mat_lit.lmcoord.y);

        float3 trace_localDir = randomNormal(uv, tex_normal);
        float cos_trace = max(dot(trace_localDir, tex_normal), 0.0);


        half3 sampleColor = half3(0.0);
        float cos_sample = 1.0;

        bool ss_hit = false;
        if (GI_ScreenTrace) {
            float dither = InterleavedGradientNoiseTime(pos);

            // float seed = InterleavedGradientNoise(pos);
            // float dither = GetR2_1D(seed * 13.0 + ap.timing.frameCounter * 137.0).x;
            float viewDist = length(localPos);

            float3 traceViewStart = mul3(ap.camera.view, offsetLocalPos);
            float3 traceClipStart = project(ap.camera.projection, traceViewStart);
            float3 screenStart = traceClipStart * 0.5 + 0.5;

            float3 traceViewEnd = mul3(ap.camera.view, offsetLocalPos + 0.1*viewDist * trace_localDir);
            float3 traceClipEnd = project(ap.camera.projection, traceViewEnd);
            float3 screenEnd = traceClipEnd * 0.5 + 0.5;

            // TODO: clip SS bounds
            // float3 screenOffset = screenEnd - screenStart;
            // float screenLen = length(screenOffset);
            float3 screenDir = normalize(screenEnd - screenStart);
            screenEnd = projectToScreenBounds(screenStart, screenDir, 16.0);
            traceClipEnd = screenEnd * 2.0 - 1.0;

            float3 traceClipPos;
            float3 traceClipPos_prev = traceClipStart;
            float2 traceScreenPos;

            const uint SS_RefineSteps = 5;

            float traceDepthL_prev = linearizeDepth(traceClipStart.z, ap.camera.near, ap.camera.far);
            for (uint i = 0; i < GI_ScreenStepCount; i++) {
                float f = (i + dither) / GI_ScreenStepCount;
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

                for (uint i = 0; i < GI_ScreenRefineCount; i++) {
                    float f = (i + dither) / GI_ScreenRefineCount;
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
                half3 ss_color = texAlbedoGB.Sample(traceScreenPos).rgb;
                sampleColor = PI * RgbToLinear(ss_color) * texDiffuse.Sample(traceScreenPos);
                // sampleColor = half3(1000,0,0);

                uint2 uv2 = uint2(traceScreenPos * ap.game.screenSize);
                // half3 sample_normal = ObjectData_Normals.unpackTex(texNormalGB[uv2].g);
                half3 sample_normal = ObjectData_Normals.unpackGeo(texNormalGB[uv2].r);
                cos_sample = max(dot(sample_normal, -trace_localDir), 0.0);

                // cos_trace = 1.0;
            }
        }

        if (!ss_hit) {
            float3 cameraFract = fract(ap.camera.position);
            int3 cameraFloor = int3(floor(ap.camera.position));

            float3 stepSizes, nextDist, stepAxis;
            float3 currPos = offsetLocalPos + cameraFract;
            DDA_init(stepSizes, nextDist, currPos, trace_localDir);

            bool hit = false;
            float traceWaterDist = 0.0;
            int3 hit_voxelMaskPos = -1;

            for (uint i = 0; i < GI_VoxelStepCount; i++) {
                float3 stepAxisNext;
                float3 step = DDA_step(stepAxisNext, nextDist, stepSizes, trace_localDir);

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
                else {
                    // TODO: build and test face mask
                    // uint enterFace = ;
                    // uint exitFace = ;
                    // if (!voxelMask.testFaces(enterFace | exitFace)) {
                    //     hit = true;
                    //     break;
                    // }
                }

                currPos += step;
                stepAxis = stepAxisNext;
            }

            float3 hit_localPos = currPos - cameraFract;


            // recreate final sample
            if (hit) {
                float3 hit_normal = -stepAxis * sign(trace_localDir);
                float3 hit_viewPos = mul3(ap.camera.view, hit_localPos);
                float3 hit_screenPos = project(ap.camera.projection, hit_viewPos) * 0.5 + 0.5;
                float hit_depth = solidDepthTex.Sample(hit_screenPos.xy);

                // TODO: these line up for now, but need a proper conversion!
                int3 hit_voxelTexPos = hit_voxelMaskPos;

                float2 voxelTexCoord = GetVoxelTexCoord(hit_normal, currPos);
                sampleColor = SampleVoxel(hit_localPos, hit_normal, hit_voxelTexPos, voxelTexCoord);

                cos_sample = max(dot(hit_normal, -trace_localDir), 0.0);
            }
            else {
                float3 skyPos = getSkyPosition(hit_localPos);
                sampleColor = sampleSkyView(skyPos, trace_localDir, scene[0].SunLocalDir);
                cos_sample = lmcoord_y;
            }

            if (traceWaterDist > 0.0)
                sampleColor *= half3(exp(-traceWaterDist * Water_AbsorbColor));
        }

        diffuse += cos_trace * cos_sample * sampleColor;
    }

    return half4(diffuse, (half)1.0);
}
