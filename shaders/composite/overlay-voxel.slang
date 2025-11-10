import aperture;
import lib.common;
import lib.dda;
import lib.sampling.IGN;
import lib.sampling.atlas;
import lib.sampling.depth;
import lib.water.common;
import lib.sky.common;
import lib.sky.sample_transmit;
import lib.sky.sample_irradiance;
import lib.sky.sample_final;
import lib.shadow;
import lib.octohedral;
import lib.voxel_tex;

extern static const bool Refract_SS_Fallback = true;
extern static const uint BLOCK_WATER;

Sampler2D<float> mainDepthTex;
Sampler2D<float> solidDepthTex;

Sampler2D<half3> texSource;
Sampler2D<half4> texFinalTranslucent;
Sampler2D<uint> texDataTranslucent;
Sampler2D<half3> texTintTranslucent;
Sampler2D<half4> texWeather;

Sampler2D<half3> blockAtlas;


[[shader("fragment")]]
float4 applyOverlays(float2 pos : SV_Position) : SV_Target0 {
    uint2 uv = uint2(pos);

    half4 weather = texWeather[uv];
    half3 tint = texTintTranslucent[uv];
    half4 translucent = texFinalTranslucent[uv];
    uint transData = texDataTranslucent[uv];

    float2 texcoord = pos / ap.game.screenSize;
    if (TAA_Enabled) texcoord += scene[0].taa_jitter;

    float transDepth = mainDepthTex[uv];
    float3 transClipPos = float3(texcoord, transDepth) * 2.0 - 1.0;
    float3 transViewPos = project(ap.camera.projectionInv, transClipPos);
    float3 transLocalPos = mul3(ap.camera.viewInv, transViewPos);
    float transDist = length(transViewPos);

    float3 viewDir = transViewPos / transDist;
    float3 localDir = transLocalPos / transDist;
    tint = RgbToLinear(tint);

    half3 opaque_color = texSource[uv];
    
    bool hasOverlay = translucent.a > 0.0;

    if (hasOverlay) {
        half4 packedTransData = unpackUnorm4x8ToHalf(transData);
        float3 refract_normal = OctDecode(packedTransData.xy);
        uint blockMapId = bitfieldExtract(transData, 24, 8);

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

        int3 hitVoxelTexPos = -1;
        int3 hitVoxelPos = 0;

        if (dot(refract_viewDir, refract_viewDir) < EPSILON) {
            opaque_color = half3(0.0);
        }
        else {
            float3 refract_localDir = mul(float3x3(ap.camera.viewInv), refract_viewDir);

            float3 cameraFract = fract(ap.camera.position);
            uint3 cameraFloor = uint3(floor(ap.camera.position));

            float3 stepSizes, nextDist, stepAxis;
            float3 traceLocalStart = (transDist + EPSILON) * localDir;
            float3 currPos = traceLocalStart + cameraFract;
            dda_init(stepSizes, nextDist, currPos, refract_localDir);

            bool hit = false;
            float traceWaterDist = EPSILON;
            float3 hitPos;

            for (uint i = 0; i < 64; i++) {
                float3 stepAxisNext;
                float3 step = dda_step(stepAxisNext, nextDist, stepSizes, refract_localDir);

                hitVoxelPos = int3(floor(fma(step, float3(0.5), currPos))) + cameraFloor;
                hitVoxelTexPos = int3(floor(VoxelTex_GetBufferPosition(currPos + 0.5*step - cameraFract)));

                var voxel = ap.voxel[hitVoxelPos];
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

            hitPos = currPos - cameraFract;
            opaque_color = half3(0.65);

            bool ss_hit = false;
            if (Refract_SS_Fallback) {
                float dither = InterleavedGradientNoiseTime(pos);

                float3 traceViewStart = mul3(ap.camera.view, traceLocalStart);
                float3 traceClipStart = project(ap.camera.projection, traceViewStart);

                float3 traceViewEnd = mul3(ap.camera.view, hitPos);
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

                if (ss_hit) opaque_color = texSource.Sample(traceScreenPos);
            }

            if (!ss_hit) {
                // recreate final sample
                if (hit) {
                    float3 hitNormal = -stepAxis * sign(refract_localDir);
                    float3 hit_viewPos = mul3(ap.camera.view, hitPos);
                    float3 hit_screenPos = project(ap.camera.projection, hit_viewPos) * 0.5 + 0.5;
                    float hit_depth = solidDepthTex.Sample(hit_screenPos.xy);

                    if (VoxelTex_InBounds(hitVoxelTexPos)) {
                        uint2 uv_min, uv_size;
                        uint voxelTex_data = texVoxelTexId[hitVoxelTexPos];
                        VoxelTex_unpack(voxelTex_data, uv_min, uv_size);

                        float2 hitCoord;
                        if (abs(hitNormal.y) > 0.5)      hitCoord = currPos.xz;
                        else if (abs(hitNormal.z) > 0.5) hitCoord = currPos.xy;
                        else                             hitCoord = currPos.zy;
                        hitCoord = 1.0 - fract(hitCoord);

                        uint3 atlasSize;
                        blockAtlas.GetDimensions(0, atlasSize.x, atlasSize.y, atlasSize.z);

                        AtlasBounds atlas;
                        atlas.CoordMin = uv_min / float2(atlasSize.xy);
                        atlas.CoordSize = uv_size / float2(atlasSize.xy);
                        float2 uv = atlas.GetAtlasCoord(hitCoord);

                        opaque_color = blockAtlas.Sample(uv).rgb;
                        opaque_color = RgbToLinear(opaque_color);

                        if (voxelTex_data == 0) {
                            // debug missing data with red albedo
                            opaque_color = half3(1.0, 0.0, 0.0);
                        }
                    }

                    half3 diffuse = half3(0.0);
                    float3 skyPos = getSkyPosition(hitPos);

                    float3 shadowLocalPos = hitNormal * 0.04 + hitPos;
                    float3 shadowViewPos = mul3(ap.celestial.view, shadowLocalPos);
                    shadowViewPos.z += 0.008;

                    int shadowCascade = GetShadowProjection(shadowViewPos, 0.05);

                    float shadow = 1.0;
                    if (shadowCascade >= 0) {
                        float3 shadowPos = mul3(ap.celestial.projection[shadowCascade], shadowViewPos);
                        shadow = SampleShadow(shadowPos * 0.5 + 0.5, shadowCascade);
                    }

                    float NoLm_sun = max(dot(hitNormal, scene[0].SunLocalDir), 0.0);
                    half3 sunTransmit = sampleSkyTransmit(skyPos, scene[0].SunLocalDir);
                    diffuse += NoLm_sun * shadow * sunTransmit * scene[0].SunColor;

                    var hitVoxel = ap.voxel[hitVoxelPos];
                    float lmcoord_y = saturate(hitVoxel.lightData.y / 15.0);
                    float3 sky_ambient = sampleSkyIrradiance(hitNormal) * lmcoord_y;// * occlusion;

                    opaque_color *= diffuse / PI + sky_ambient;
                }
                else {
                    opaque_color = sampleSkyFinal(hitPos, refract_localDir, false);
                }
            }

            opaque_color *= half3(exp(-traceWaterDist * Water_AbsorbColor));
        }
    }

    half3 final_color = opaque_color;
    if (hasOverlay) {
        final_color = fma(final_color, half3(1.0 - translucent.a), translucent.rgb);
    }

    if (ap.camera.fluid == 1) {
        half3 opaqueWaterTint = half3(exp(-(transDist + EPSILON) * Water_AbsorbColor));
        final_color *= opaqueWaterTint;
    }
    
    final_color.rgb += weather.rgb * half3(0.25);

    return half4(final_color, half2(1.0).x);
}
