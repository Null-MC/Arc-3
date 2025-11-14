import aperture;
import buffers.ObjectData;
import lib.common;
import lib.material.pbr;
import lib.material.rough_normal;
import lib.light.fresnel;
import lib.sampling.atlas;
import lib.sampling.depth;
import lib.sampling.IGN;
import lib.sampling.R2;
import lib.shadow;
import lib.sky.common;
import lib.sky.sample_transmit;
import lib.sky.sample_irradiance;
import lib.sky.sample_view;
import lib.voxel_tex;
import lib.dda;

extern static const bool GI_ScreenTrace;
extern static const bool World_HasSky;
extern static const uint BLOCK_WATER;

Sampler2D<float> solidDepthTex;
// Sampler2D<half3> texReprojection;
// Sampler2D<half4> texGI_prev;
Sampler2D<half3> texDiffuse;

Sampler2D<half4> texAlbedoGB;
Sampler2D<uint2> texNormalGB;
Sampler2D<uint2> texMatLightGB;

Sampler2D<half3> blockAtlas;


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
        float cos_trace = dot(trace_localDir, tex_normal);

        float3 cameraFract = fract(ap.camera.position);
        int3 cameraFloor = int3(floor(ap.camera.position));

        float3 stepSizes, nextDist, stepAxis;
        float3 currPos = offsetLocalPos + cameraFract;
        dda_init(stepSizes, nextDist, currPos, trace_localDir);

        bool hit = false;
        float traceWaterDist = EPSILON;
        int3 hit_voxelTexPos = -1;
        int3 hit_voxelPos = 0;

        for (uint i = 0; i < 16; i++) {
            float3 stepAxisNext;
            float3 step = dda_step(stepAxisNext, nextDist, stepSizes, trace_localDir);

            hit_voxelPos = int3(floor(fma(step, float3(0.5), currPos))) + cameraFloor;
            hit_voxelTexPos = int3(floor(VoxelTex_GetBufferPosition(currPos + 0.5*step - cameraFract)));

            var voxel = ap.voxel[hit_voxelPos];
            if (voxel.blockId > 0) {
                if (voxel.block.isFullBlock) {
                    hit = true;
                    break;
                }
                else if (voxel.block.customId == BLOCK_WATER) {
                    traceWaterDist += length(step);
                }
            }

            // TODO: use custom voxelTex lookup to verify builtin is broken

            // hitVoxel = int3(floor(VoxelTex_GetBufferPosition(currPos + 0.5*step - cameraFract)));

            // if (texVoxelTexId[hitVoxel] != 0) {
            //     hit = true;
            //     break;
            // }

            currPos += step;
            stepAxis = stepAxisNext;
        }

        float3 hit_localPos = currPos - cameraFract;
        half3 sampleColor = half3(0.0);
        float cos_sample = 1.0;

        bool ss_hit = false;
        if (GI_ScreenTrace) {
            // float dither = InterleavedGradientNoiseTime(pos);

            float seed = InterleavedGradientNoise(pos);
            float dither = GetR2_1D(seed * 13.0 + ap.timing.frameCounter * 137.0).x;

            float3 traceViewStart = mul3(ap.camera.view, offsetLocalPos);
            float3 traceClipStart = project(ap.camera.projection, traceViewStart);

            float3 traceViewEnd = mul3(ap.camera.view, hit_localPos);
            float3 traceClipEnd = project(ap.camera.projection, traceViewEnd);

            float3 traceClipPos;
            float3 traceClipPos_prev = traceClipStart;
            float2 traceScreenPos;

            const uint SS_StepCount = 24;
            const uint SS_RefineSteps = 6;

            // bool hit = false;
            float traceDepthL_prev = linearizeDepth(traceClipStart.z, ap.camera.near, ap.camera.far);
            for (uint i = 1; i < SS_StepCount; i++) {
                float f = (i + dither) / SS_StepCount;
                traceClipPos = lerp(traceClipStart, traceClipEnd, f);
                traceScreenPos = traceClipPos.xy * 0.5 + 0.5;
                if (!all(saturate(traceScreenPos) == traceScreenPos)) break;

                float sampleClipDepth = solidDepthTex.Sample(traceScreenPos) * 2.0 - 1.0;
                float screenDepthL = linearizeDepth(sampleClipDepth, ap.camera.near, ap.camera.far);
                float traceDepthL = linearizeDepth(traceClipPos.z, ap.camera.near, ap.camera.far);

                float stepMaxZ = abs(traceDepthL - traceDepthL_prev);

                if (abs(screenDepthL - traceDepthL) < stepMaxZ) {
                    ss_hit = true;
                    hit = true;
                    break;
                }

                traceClipPos_prev = traceClipPos;
                traceDepthL_prev = traceDepthL;
            }

            // if (ss_hit) {
            //     traceClipStart = traceClipPos_prev;
            //     traceClipEnd = traceClipPos;

            //     for (uint i = 0; i < SS_RefineSteps; i++) {
            //         float f = (i + dither) / SS_RefineSteps;
            //         traceClipPos = lerp(traceClipStart, traceClipEnd, f);
            //         traceScreenPos = traceClipPos.xy * 0.5 + 0.5;
            //         if (!all(saturate(traceScreenPos) == traceScreenPos)) break;

            //         float sampleClipDepth = solidDepthTex.Sample(traceScreenPos) * 2.0 - 1.0;
            //         float screenDepthL = linearizeDepth(sampleClipDepth, ap.camera.near, ap.camera.far);
            //         float traceDepthL = linearizeDepth(traceClipPos.z, ap.camera.near, ap.camera.far);

            //         float stepMaxZ = abs(traceDepthL - traceDepthL_prev);

            //         if (abs(screenDepthL - traceDepthL) < stepMaxZ) {
            //             break;
            //         }
            //     }
            // }

            if (ss_hit) {
                half3 ss_color = texAlbedoGB.Sample(traceScreenPos).rgb;
                sampleColor = RgbToLinear(ss_color) * texDiffuse.Sample(traceScreenPos);

                // TODO: this should help but made worse
                // uint2 uv2 = uint2(traceScreenPos * ap.game.screenSize);
                // half3 sample_normal = ObjectData_Normals.unpackTex(texNormalGB[uv2].g);
                // cos_sample = max(dot(sample_normal, -trace_localDir), 0.0);
            }
        }

        if (!ss_hit) {
            // recreate final sample
            float3 skyPos = getSkyPosition(hit_localPos);

            if (hit) {
                float3 hit_normal = -stepAxis * sign(trace_localDir);
                float3 hit_viewPos = mul3(ap.camera.view, hit_localPos);
                float3 hit_screenPos = project(ap.camera.projection, hit_viewPos) * 0.5 + 0.5;
                float hit_depth = solidDepthTex.Sample(hit_screenPos.xy);

                if (VoxelTex_InBounds(hit_voxelTexPos)) {
                    uint2 uv_min, uv_size;
                    uint voxelTex_data = texVoxelTexId[hit_voxelTexPos];
                    VoxelTex_unpack(voxelTex_data, uv_min, uv_size);

                    float2 hitCoord;
                    if (abs(hit_normal.y) > 0.5)      hitCoord = currPos.xz;
                    else if (abs(hit_normal.z) > 0.5) hitCoord = currPos.xy;
                    else                              hitCoord = currPos.zy;
                    hitCoord = 1.0 - fract(hitCoord);

                    uint3 atlasSize;
                    blockAtlas.GetDimensions(0, atlasSize.x, atlasSize.y, atlasSize.z);

                    AtlasBounds atlas;
                    atlas.CoordMin = uv_min / float2(atlasSize.xy);
                    atlas.CoordSize = uv_size / float2(atlasSize.xy);
                    float2 uv = atlas.GetAtlasCoord(hitCoord);

                    sampleColor = blockAtlas.Sample(uv).rgb;
                    sampleColor = RgbToLinear(sampleColor);

                    if (voxelTex_data == 0) {
                        // debug missing data with red albedo
                        sampleColor = half3(0.0);// half3(1, 0, 0);
                    }
                }

                half3 diffuse = half3(0.0);

                float3 shadowLocalPos = hit_normal * 0.04 + hit_localPos;
                float3 shadowViewPos = mul3(ap.celestial.view, shadowLocalPos);
                shadowViewPos.z += 0.008;

                int shadowCascade = GetShadowProjection(shadowViewPos, 0.05);

                half3 shadow = half3(1.0);
                if (shadowCascade >= 0) {
                    float3 shadowPos = mul3(ap.celestial.projection[shadowCascade], shadowViewPos);
                    shadow = SampleShadowColor(shadowPos * 0.5 + 0.5, shadowCascade);
                }

                if (World_HasSky) {
                    float NoLm_sun = max(dot(hit_normal, scene[0].SunLocalDir), 0.0);
                    half3 sunTransmit = sampleSkyTransmit(skyPos, scene[0].SunLocalDir);
                    diffuse += NoLm_sun * shadow * sunTransmit * scene[0].SunColor;

                    var hitVoxel = ap.voxel[hit_voxelPos];
                    float hit_lmcoord_y = saturate(hitVoxel.lightData.y / 15.0);
                    float3 sky_ambient = sampleSkyIrradiance(hit_normal) * hit_lmcoord_y;
                }

                sampleColor *= diffuse;

                cos_sample = max(dot(hit_normal, -trace_localDir), 0.0);
            }
            else {
                sampleColor = sampleSkyView(skyPos, trace_localDir, scene[0].SunLocalDir);
                cos_sample = lmcoord_y;
            }
        }

        diffuse += cos_trace * cos_sample * sampleColor;
    }

    // half3 reproj = texReprojection[uv];
    // float2 prev_texcoord = (pos + reproj.xy) / ap.game.screenSize;

    // float4 gi_prev = texGI_prev.Sample(prev_texcoord);

    // float counter = clamp(gi_prev.a * reproj.b, 0, GI_MaxFrames);
    // diffuse = lerp(gi_prev.rgb, diffuse, rcp(counter + 1));

    // DEBUG
    // imgDebug[uv] = half4(diffuse * 0.02, (half)1.0);

    return half4(diffuse, (half)1.0);
}
