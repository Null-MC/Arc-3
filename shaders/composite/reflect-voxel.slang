import aperture;
import buffers.ObjectData;
import lib.common;
import lib.material.pbr;
import lib.material.rough_normal;
import lib.light.fresnel;
import lib.sampling.depth;
import lib.sampling.IGN;
import lib.sky.sample_final;
import lib.water.common;
import lib.voxel.voxel_tex;
import lib.voxel.voxel_sample;
import lib.dda;

extern static const int RefractMode;
extern static const bool Reflect_Rough;
extern static const bool Reflect_SS_Fallback;
extern static const uint BLOCK_WATER;

Sampler2D<float> mainDepthTex;
Sampler2D<half3> texSource;

Sampler2D<half4> texAlbedoGB_translucent;
Sampler2D<uint2> texNormalGB_translucent;
Sampler2D<uint2> texMatLightGB_translucent;


[[shader("fragment")]]
half4 applyReflections(float2 pos : SV_Position) : SV_Target0 {
    uint2 uv = uint2(pos);
    float depth = mainDepthTex[uv];
    half3 finalColor = texSource[uv];
    half4 colorData = texAlbedoGB_translucent[uv];
    
    if (colorData.a > 0.0) {
        uint normalDataG = texNormalGB_translucent[uv].g;
        uint2 matLitData = texMatLightGB_translucent[uv];

        float2 texcoord = pos / ap.game.screenSize;
        if (TAA_Enabled) texcoord -= scene[0].taa_jitter;

        float3 screenPos = float3(texcoord, depth);
        float3 clipPos = screenPos * 2.0 - 1.0;
        float3 viewPos = project(ap.camera.projectionInv, clipPos);
        float3 localPos = mul3(ap.camera.viewInv, viewPos);

        half3 tex_normal = ObjectData_Normals.unpackTex(normalDataG);

        ObjectData_MatLit mat_lit;
        mat_lit.unpack(matLitData);

        half3 albedo = RgbToLinear(colorData.rgb);
        half roughness = mat_roughness(mat_lit.specular.r);
        half f0_metal = mat_f0_metal(mat_lit.specular.g);
        half metalness = (half)mat_metalness(f0_metal);

        half lmcoord_y = pow2(mat_lit.lmcoord.y);
        half roughL = pow2(roughness);

        float dither = InterleavedGradientNoiseTime(pos);

        float3 reflectNormal = Reflect_Rough
            ? randomizeNormal(uv, tex_normal, roughL)
            : tex_normal;
        
        float viewDist = length(viewPos);
        float3 viewDir = viewPos / viewDist;
        float3 viewNormal = mul(float3x3(ap.camera.view), reflectNormal);
        float3 reflect_viewDir = reflect(viewDir, viewNormal);
        float3 reflect_localDir = mul(float3x3(ap.camera.viewInv), reflect_viewDir);



        float3 cameraFract = fract(ap.camera.position);
        int3 cameraFloor = int3(floor(ap.camera.position));

        float3 stepSizes, nextDist, stepAxis;
        // float3 traceLocalStart = localPos;
        float3 localDir = normalize(localPos);
        float3 currPos = localPos + cameraFract - localDir*0.02;
        DDA_init(stepSizes, nextDist, currPos, reflect_localDir);

        bool hit = false;
        float traceWaterDist = EPSILON;
        int3 hit_voxelTexPos = -1;
        int3 hit_voxelPos = 0;
        float3 hit_localPos;

        if (ap.camera.fluid == 1) traceWaterDist += viewDist;

        for (uint i = 0; i < 64; i++) {
            float3 stepAxisNext;
            float3 step = DDA_step(stepAxisNext, nextDist, stepSizes, reflect_localDir);

            hit_voxelPos = int3(floor(fma(step, float3(0.5), currPos))) + cameraFloor;
            hit_voxelTexPos = int3(floor(VoxelTex_GetBufferPosition(currPos + 0.5*step - cameraFract)));

            // var voxel = ap.voxel[hit_voxelPos];
            // if (voxel.blockId > 0) {
            //     if (voxel.block.isFullBlock) {
            //         hit = true;
            //         break;
            //     }
            //     else if (voxel.block.customId == BLOCK_WATER) {
            //         traceWaterDist += length(step);
            //     }
            // }

            // TODO: use custom voxelTex lookup to verify builtin is broken

            uint voxelIndex = VoxelTex_GetBufferIndex(hit_voxelTexPos);
            if (voxelTexBuffer[voxelIndex].r != 0) {
                hit = true;
                break;
            }

            currPos += step;
            stepAxis = stepAxisNext;
        }

        hit_localPos = currPos - cameraFract;
        half3 reflectColor = half3(0.65);

        bool ss_hit = false;
        if (Reflect_SS_Fallback) {
            float3 reflect_viewPos = 0.5 * viewDist * reflect_viewDir + viewPos;
            float3 reflect_clipPos = project(ap.camera.projection, reflect_viewPos);
            float3 reflect_screenPos = reflect_clipPos * 0.5 + 0.5;

            float3 screenDir = normalize(reflect_screenPos - screenPos);

            // project the reflected trace direction to edge of trace bounds
            float3 screenEnd = projectToScreenBounds(screenPos, screenDir);
            float3 traceClipEnd = screenEnd * 2.0 - 1.0;
            float3 traceClipStart = clipPos;

            float3 traceClipPos;
            float3 traceClipPos_prev = traceClipStart;
            float2 traceScreenPos;

            const uint SS_StepCount = 24;
            const uint SS_RefineSteps = 8;

            // bool hit = false;
            float traceDepthL_prev = linearizeDepth(traceClipStart.z, ap.camera.near, ap.camera.far);
            for (uint i = 1; i < SS_StepCount; i++) {
                float f = (i + dither) / SS_StepCount;
                traceClipPos = lerp(traceClipStart, traceClipEnd, f);
                traceScreenPos = traceClipPos.xy * 0.5 + 0.5;
                if (!all(saturate(traceScreenPos) == traceScreenPos)) break;

                float sampleClipDepth = mainDepthTex.Sample(traceScreenPos) * 2.0 - 1.0;
                float screenDepthL = linearizeDepth(sampleClipDepth, ap.camera.near, ap.camera.far);
                float traceDepthL = linearizeDepth(traceClipPos.z, ap.camera.near, ap.camera.far);

                if (screenDepthL < traceDepthL) {
                    ss_hit = true;
                    hit = true;
                    break;
                }

                traceClipPos_prev = traceClipPos;
                traceDepthL_prev = traceDepthL;
            }

            if (ss_hit) {
                traceClipStart = traceClipPos_prev;
                traceClipEnd = traceClipPos;

                for (uint i = 0; i < SS_RefineSteps; i++) {
                    float f = (i + dither) / SS_RefineSteps;
                    traceClipPos = lerp(traceClipStart, traceClipEnd, f);
                    traceScreenPos = traceClipPos.xy * 0.5 + 0.5;
                    if (!all(saturate(traceScreenPos) == traceScreenPos)) break;

                    float sampleClipDepth = mainDepthTex.Sample(traceScreenPos) * 2.0 - 1.0;
                    float screenDepthL = linearizeDepth(sampleClipDepth, ap.camera.near, ap.camera.far);
                    float traceDepthL = linearizeDepth(traceClipPos.z, ap.camera.near, ap.camera.far);

                    if (screenDepthL < traceDepthL) {
                        break;
                    }
                }
            }

            if (ss_hit) reflectColor = texSource.Sample(traceScreenPos);
        }

        if (!ss_hit) {
            // recreate final sample
            if (hit) {
                float3 hit_normal = -stepAxis * sign(reflect_localDir);
                float3 hit_viewPos = mul3(ap.camera.view, hit_localPos);
                float3 hit_screenPos = project(ap.camera.projection, hit_viewPos) * 0.5 + 0.5;
                float hit_depth = mainDepthTex.Sample(hit_screenPos.xy);

                float2 voxelTexCoord = GetVoxelTexCoord(hit_normal, currPos);
                reflectColor = SampleVoxel(hit_localPos, hit_normal, hit_voxelTexPos, voxelTexCoord);
            }
            else {
                reflectColor = sampleSkyFinal(hit_localPos, reflect_localDir, false);
            }
        }

        reflectColor *= half3(exp(-traceWaterDist * Water_AbsorbColor));

        half3 f0 = lerp(half3(f0_metal), albedo.rgb, metalness);

        // half3 localDir = half3(normalize(localPos));
        half NoVm = max(dot(reflectNormal, -localDir), (half)0.0);
        half3 F_NoV = F_schlickRough(NoVm, f0, roughL);
        half3 specular_tint = lerp((half)1.0, albedo, metalness);

        // imgDebug[uv] = float4(LinearToRgb(reflectColor * 0.008), 1.0);

        finalColor += F_NoV * ((half)1.0 - roughL) * reflectColor * specular_tint;
    }

    return half4(finalColor, (half)1.0);
}
