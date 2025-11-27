import aperture;
import buffers.ObjectData;
import lib.common;
import lib.noise.IGN;
import lib.noise.hash;
import lib.material.pbr;
import lib.material.rough_normal;
import lib.light.fresnel;
import lib.sampling.depth;
import lib.sampling.R2;
import lib.sky.common;
import lib.sky.sample_view;
import lib.water.common;
import lib.voxel.voxel_common;
import lib.voxel.voxel_mask;
import lib.voxel.voxel_sample;
import lib.voxel.dda;
import lib.screen_trace;

import lib.sky.sample_irradiance;

extern static const int GI_SampleCount;
extern static const int GI_VoxelStepCount;
extern static const int GI_ScreenStepCount;
extern static const int GI_RefineStepCount;
extern static const bool GI_ScreenTrace;
extern static const int BufferWidth;
extern static const int BufferHeight;
extern static const int BufferScale;

static const float2 BufferSize = float2(BufferWidth, BufferHeight);

StructuredBuffer<VoxelMask> VoxelMaskBuffer;

Sampler2D<float> solidDepthTex;
Sampler2D<half3> texDiffuse;

Sampler2D<half4> texAlbedoGB;
Sampler2D<uint2> texNormalGB;
Sampler2D<uint2> texMatLightGB;


bool between(const in float value, const in float _min, const in float _max) {
    if (_max >= _min) return value > _min && value <= _max;
    else return value >= _max && value < _min;
}

float3 sample_cosine_weighted_hemisphere(const in float2 rand, out float pdf) {
    float2 p = rand * 2.0 - 1.0;
    
    // Use concentric disk mapping to avoid distortion artifacts in uniform disk sampling
    // This example uses simple square-to-disk for clarity, but a proper
    // concentric mapping (as mentioned in PBRT) is better for production.
    // For simplicity here, we'll use the basic polar approach with sqrt for r:
    float r = sqrt(rand.x);
    float phi = 2.0 * PI * rand.y;

    float3 dir;
    dir.x = r * cos(phi);
    dir.y = r * sin(phi);
    dir.z = sqrt(max(1.0 - dot(dir.xy, dir.xy), 0.0));
    
    pdf = dir.z;// / PI;

    return dir;
}

float3 transform_to_world(const in float3 normal, const in float3 local_dir) {
    float sign = sign(normal.z);
    if (abs(normal.z) < EPSILON) sign = 1.0;

    float a = -rcp(sign + normal.z);
    float b = normal.x * normal.y * a;
    float3 tangent = float3(1.0 + sign * normal.x * normal.x * a, sign * b, -sign * normal.x);
    float3 bitangent = float3(b, sign + normal.y * normal.y * a, -normal.y);

    float3x3 tbn = float3x3(tangent, bitangent, normal);

    return mul(local_dir, tbn);
}


[[shader("fragment")]]
half4 applyGI(float2 pos : SV_Position) : SV_Target0 {
    uint2 uv_full = uint2(pos) * BufferScale;

    if (BufferScale > 1) {
        uv_full += (ap.timing.frameCounter % 2) * BufferScale;
    }

    // float2 texcoord = pos / BufferSize;
    float depth = solidDepthTex[uv_full];
    float3 diffuse = 0.0;
    
    if (depth < 1.0) {
        float2 texcoord = uv_full / float2(ap.game.screenSize);
        if (TAA_Enabled) texcoord -= scene[0].taa_jitter;

        float3 clipPos = float3(texcoord, depth) * 2.0 - 1.0;
        // float3 viewPos = project(ap.camera.projectionInv, clipPos);
        // float3 localPos = mul3(ap.camera.viewInv, viewPos);
        float3 localPos = project(scene[0].viewProjectionInv, clipPos);

        float viewDist = length(localPos);
        float3 localDir = localPos / viewDist;
        float3 offsetLocalPos = localPos - 0.02*viewDist*localDir;

        half3 tex_normal = ObjectData_Normals.unpackTex(texNormalGB[uv_full].g);

        ObjectData_MatLit mat_lit;
        mat_lit.unpack(texMatLightGB[uv_full]);

        float dither = InterleavedGradientNoiseTime(pos);

        [ForceUnroll]
        for (int i = 0; i < GI_SampleCount; i++) {
        // float3 trace_localDir = randomNormal(pos, tex_normal);
        // float cos_trace = max(dot(trace_localDir, tex_normal), 0.0);

        float pdf;
        float2 seed = hash22(pos + float2(23.0, 47.0)*(ap.timing.frameCounter + i*3));
        float3 trace_tangentDir = sample_cosine_weighted_hemisphere(seed, pdf);
        float3 trace_localDir = transform_to_world(tex_normal, trace_tangentDir);


        half3 sampleColor = half3(0.0);
        float cos_sample = 1.0;

        bool ss_hit = false;
        if (GI_ScreenTrace) {
            float3 trace_viewDir = mul(float3x3(ap.camera.view), trace_localDir);
            trace_viewDir = normalize(trace_viewDir);
            
            // float seed = InterleavedGradientNoise(pos);
            // float dither = GetR2_1D(seed * 13.0 + ap.timing.frameCounter * 137.0).x;

            float3 traceViewStart = mul3(ap.camera.view, offsetLocalPos);
            float3 traceClipStart = project(ap.camera.projection, traceViewStart);
            float3 screenStart = traceClipStart * 0.5 + 0.5;

            // float3 screenEnd = projectScreenTrace(traceViewStart, screenStart, trace_viewDir, 8.0);
            // float3 traceClipEnd = screenEnd * 2.0 - 1.0;

            float traceDist = clamp(viewDist * 0.25, 0.0, 8.0);
            float3 traceViewEnd = traceViewStart + traceDist * trace_viewDir;
            float3 traceClipEnd = project(ap.camera.projection, traceViewEnd);

            float3 traceClipPos;
            float3 traceClipPos_prev = traceClipStart;
            float2 traceScreenPos;

            float traceDepthL_prev = linearizeDepth(traceClipStart.z, ap.camera.near, ap.camera.far);
            for (uint i = 0; i < GI_ScreenStepCount; i++) {
                float f = (i + dither) / GI_ScreenStepCount;
                traceClipPos = lerp(traceClipStart, traceClipEnd, f);
                traceScreenPos = traceClipPos.xy * 0.5 + 0.5;
                if (!all(saturate(traceScreenPos) == traceScreenPos)) break;

                float sampleClipDepth = solidDepthTex.Sample(traceScreenPos) * 2.0 - 1.0;
                float screenDepthL = linearizeDepth(sampleClipDepth, ap.camera.near, ap.camera.far);
                float traceDepthL = linearizeDepth(traceClipPos.z, ap.camera.near, ap.camera.far);

                // if (abs(screenDepthL - traceDepthL) < abs(traceDepthL - traceDepthL_prev)) {
                // if (between(screenDepthL, traceDepthL_prev, traceDepthL)) {
                if (traceDepthL > screenDepthL && traceDepthL - screenDepthL < abs(traceDepthL - traceDepthL_prev)) {
                    ss_hit = true;
                    break;
                }

                traceClipPos_prev = traceClipPos;
                traceDepthL_prev = traceDepthL;
            }

            if (ss_hit) {
                traceClipStart = traceClipPos_prev;
                traceClipEnd = traceClipPos;

                for (uint i = 0; i < GI_RefineStepCount; i++) {
                    float f = (i + dither) / GI_RefineStepCount;
                    traceClipPos = lerp(traceClipStart, traceClipEnd, f);
                    traceScreenPos = traceClipPos.xy * 0.5 + 0.5;
                    if (!all(saturate(traceScreenPos) == traceScreenPos)) break;

                    float sampleClipDepth = solidDepthTex.Sample(traceScreenPos) * 2.0 - 1.0;
                    float screenDepthL = linearizeDepth(sampleClipDepth, ap.camera.near, ap.camera.far);
                    float traceDepthL = linearizeDepth(traceClipPos.z, ap.camera.near, ap.camera.far);

                    // if (abs(screenDepthL - traceDepthL) < abs(traceDepthL - traceDepthL_prev)) {
                    // if (between(screenDepthL, traceDepthL_prev, traceDepthL)) {
                    if (traceDepthL > screenDepthL && traceDepthL - screenDepthL < abs(traceDepthL - traceDepthL_prev)) {
                        break;
                    }
                }
            }

            if (ss_hit) {
                half3 trace_albedo = texAlbedoGB.Sample(traceScreenPos).rgb;
                half3 trace_diffuse = texDiffuse.Sample(traceScreenPos);
                sampleColor = RgbToLinear(trace_albedo) * trace_diffuse * PI;

                uint2 uv2 = uint2(traceScreenPos * ap.game.screenSize);
                half3 sample_normal = ObjectData_Normals.unpackTex(texNormalGB[uv2].g);
                // half3 sample_normal = ObjectData_Normals.unpackGeo(texNormalGB[uv2].r);
                cos_sample = step(0.0, dot(sample_normal, -trace_localDir));
            }
        }

        float traceWaterDist = 0.0;
        // float traceOcclusionDist = 0.0;
        half3 trace_tint = half3(1.0);

        bool hit = false;
        if (!ss_hit) {
            float3 cameraFract = fract(ap.camera.position);
            int3 cameraFloor = int3(floor(ap.camera.position));

            float3 stepSizes, nextDist;
            float3 currPos = offsetLocalPos + cameraFract;
            DDA_init(stepSizes, nextDist, currPos, trace_localDir);

            int3 hit_voxelMaskPos = -1;
            bool isLastBlockWater = ap.camera.fluid == 1;
            float3 stepAxis = 0.0;
            VoxelMask voxelMask;

            for (uint i = 0; i < GI_VoxelStepCount; i++) {
                float3 stepAxisNext;
                float3 step = DDA_step(stepAxisNext, nextDist, stepSizes, trace_localDir);

                hit_voxelMaskPos = int3(floor(Voxel_GetBufferPosition(currPos + 0.5*step - cameraFract)));

                if (i > 0) {
                    // check exit face mask
                    float3 axisNormal = stepAxis * sign(trace_localDir);
                    if (voxelMask.testFace(axisNormal)) {hit = true; break;}
                }

                bool isWater = false;
                if (Voxel_InBufferBounds(hit_voxelMaskPos)) {
                    uint voxelIndex = Voxel_GetBufferIndex(hit_voxelMaskPos);
                    voxelMask = VoxelMaskBuffer[voxelIndex];
                    uint maskId = voxelMask.getId();

                    isWater = maskId == MaskId_Water;
                    // float stepLength = length(step);

                    if (maskId == MaskId_Solid) {
                        hit = true;
                        break;
                    }
                    // else if (maskId == MaskId_Partial) {
                    //     traceOcclusionDist += stepLength;
                    // }
                    else if (isWater) {
                        traceWaterDist += length(step);
                    }
                    else if (maskId == MaskId_Tint) {
                        trace_tint *= voxelMask.getTint();
                    }

                    if (!all(stepAxis == 0)) {
                        // check enter face mask
                        float3 axisNormal = -stepAxis * sign(trace_localDir);
                        if (voxelMask.testFace(axisNormal)) {hit = true; break;}
                    }
                }

                currPos += step;
                stepAxis = stepAxisNext;
                isLastBlockWater = isWater;
            }

            // recreate final sample
            if (hit) {
                float3 hit_localPos = currPos - cameraFract;
                float3 hit_localNormal = -stepAxis * sign(trace_localDir);
                half hit_wetness = (half)isLastBlockWater;

                float3 hit_viewPos = mul3(ap.camera.view, hit_localPos);
                float3 hit_screenPos = project(ap.camera.projection, hit_viewPos) * 0.5 + 0.5;
                float hit_depth = solidDepthTex.Sample(hit_screenPos.xy);

                float2 voxelTexCoord = GetVoxelTexCoord(hit_localNormal, currPos);
                sampleColor = SampleVoxel(hit_localPos, hit_localNormal, hit_voxelMaskPos, voxelTexCoord, hit_wetness, true);

                cos_sample = 1.0;// max(dot(hit_normal, -trace_localDir), 0.0);
            }
        }

        if (!hit && !ss_hit) {
            half lmcoord_y = pow2(mat_lit.lmcoord.y);

            float3 skyPos = getSkyPosition(localPos);
            sampleColor = sampleSkyView(skyPos, trace_localDir, scene[0].SunLocalDir);
            // sampleColor = sampleSkyIrradiance(trace_localDir);
            cos_sample = lmcoord_y;
        }

        sampleColor *= RgbToLinear(trace_tint);

        if (traceWaterDist > 0.0)
            sampleColor *= half3(exp(-traceWaterDist * Water_AbsorbColor));

        // if (traceOcclusionDist > 0.0)
        //     sampleColor *= (half)exp(-0.2 * traceOcclusionDist);

        diffuse += pdf * cos_sample * sampleColor;
        }
    }

    return half4(half3(diffuse / GI_SampleCount), (half)1.0);
}
