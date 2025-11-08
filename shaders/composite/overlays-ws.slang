import aperture;
import lib.common;
import lib.dda;
import lib.sampling.IGN;
import lib.sampling.atlas;
import lib.sampling.depth;
import lib.water.common;
import lib.water.water_depth;
import lib.sky.common;
import lib.sky.sample_transmit;
import lib.sky.sample_irradiance;
import lib.sky.sample_final;
import lib.shadow;
import lib.voxel_tex;

// extern static const int RefractMode;
extern static const int REFRACTION_STEPS = 16;
extern static const bool WS_SS_Fallback = false;
extern static const uint BLOCK_WATER;

// static const int Refract_WorldSpace = 2;
// static const int Refract_ScreenSpace = 1;
// static const int Refract_None = 0;


Sampler2D<float> mainDepthTex;
Sampler2D<float> solidDepthTex;

Sampler2D<half3> texSource;
Sampler2D<half4> texFinalTranslucent;
Sampler2D<uint> texDataTranslucent;
Sampler2D<half3> texTintTranslucent;
Sampler2D<half4> texWeather;

Sampler2D<half3> blockAtlas;

// [[vk::image_format("rgba8")]]
// RWTexture2D<float4> imgDebug;


[[shader("fragment")]]
float4 applyOverlays(float2 pos : SV_Position) : SV_Target0 {
    uint2 uv = uint2(pos);

    half4 weather = texWeather[uv];
    half3 tint = texTintTranslucent[uv];
    half4 translucent = texFinalTranslucent[uv];
    uint transData = texDataTranslucent[uv];

    float2 texcoord = pos / ap.game.screenSize;
    if (TAA_Enabled) texcoord -= scene[0].taa_jitter;

    float transDepth = mainDepthTex[uv];
    float opaqueDepth = solidDepthTex[uv];

    float3 opaqueClipPos = float3(texcoord, opaqueDepth) * 2.0 - 1.0;
    float3 opaqueViewPos = project(ap.camera.projectionInv, opaqueClipPos);
    // // float3 localPos = mul3(ap.camera.viewInv, viewPos);

    float3 transClipPos = float3(texcoord, transDepth) * 2.0 - 1.0;
    float3 transViewPos = project(ap.camera.projectionInv, transClipPos);
    float3 transLocalPos = mul3(ap.camera.viewInv, transViewPos);

    float3 viewDir = normalize(transViewPos);
    float3 localDir = normalize(transLocalPos);
    tint = RgbToLinear(tint);

    uint2 water_uv = uv;
    float2 refract_texcoord = texcoord;
    float waterDist = WaterDepth_get(uv);
    float transDist = length(transViewPos);
    half3 opaque_color = texSource[uv];

    bool hasRefract = translucent.a > 0.0 || waterDist < min(transDist, ap.camera.far);
    if (hasRefract) {
        uint normalData = transDist < waterDist
            ? transData : texWaterNormal[uv];

        float3 refract_normal = unpackUnorm4x8ToFloat(normalData).xyz;
        refract_normal = normalize(refract_normal * 2.0 - 1.0);

        const float IOR_AIR   = 1.0003;
        const float IOR_WATER   = 1.333;
        const float IOR_DEFAULT = 1.5;
        // TODO: store and use actual translucent IOR
        const float ETA_AIR_TO_WATER = (IOR_AIR/IOR_WATER);
        const float ETA_WATER_TO_AIR = 1.02;// (IOR_WATER/IOR_AIR);
        float eta = ap.camera.fluid == 1 ? ETA_WATER_TO_AIR : ETA_AIR_TO_WATER;

        float3 refract_viewNormal = mul(float3x3(ap.camera.view), refract_normal);
        float3 refract_viewDir = refract(viewDir, refract_viewNormal, eta);
        float3 refract_viewPos = min(transDist, waterDist) * viewDir;

        int3 hitVoxelTexPos = -1;
        int3 hitVoxelPos = 0;

        if (dot(refract_viewDir, refract_viewDir) < EPSILON) {
            refract_texcoord = -1.0;
            opaque_color = half3(0.0);
        }
        else {
            float3 refract_localDir = mul(float3x3(ap.camera.viewInv), refract_viewDir);
            //float3 refract_localPos = mul3(ap.camera.viewInv, refract_viewPos);

            float3 cameraFract = fract(ap.camera.position);
            uint3 cameraFloor = uint3(floor(ap.camera.position));

            float3 stepSizes, nextDist, stepAxis;
            float3 traceLocalStart = (min(transDist, waterDist) + EPSILON) * localDir;
            float3 currPos = traceLocalStart + cameraFract;
            dda_init(stepSizes, nextDist, currPos, refract_localDir);

            bool hit = false;
            float traceWaterDist = EPSILON;
            float3 hitPos;

            float dither = InterleavedGradientNoiseTime(pos);

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
            if (WS_SS_Fallback) {
                //float3 stepLocalStart = traceLocalStart;
                float3 stepViewStart = mul3(ap.camera.view, traceLocalStart);
                float3 stepClipStart = project(ap.camera.projection, stepViewStart);
                // float3 stepScreenStart = stepClipStart * 0.5 + 0.5;

                // float3 stepLocalEnd = hitPos;
                float3 stepViewEnd = mul3(ap.camera.view, hitPos);
                float3 stepClipEnd = project(ap.camera.projection, stepViewEnd);
                // float3 stepScreenEnd = stepClipEnd * 0.5 + 0.5;

                const uint SS_StepCount = 16;
                float stepMaxZ = abs(stepViewEnd.z - stepViewStart.z) / SS_StepCount;

                // TODO: SS trace
                for (uint i2 = 0; i2 < SS_StepCount; i2++) {
                    float f = (i2 + dither) / SS_StepCount;
                    float3 sub_clipPos = lerp(stepClipStart, stepClipEnd, f);
                    float2 sub_screenPos = sub_clipPos.xy * 0.5 + 0.5;

                    float screenDepth = solidDepthTex.Sample(sub_screenPos);
                    float screenDepthL = linearizeDepth(screenDepth * 2.0 - 1.0, ap.camera.near, ap.camera.far);
                    float traceDepthL = linearizeDepth(sub_clipPos.z, ap.camera.near, ap.camera.far);

                    if (abs(screenDepthL - traceDepthL) < stepMaxZ) {
                        hit = true;
                        ss_hit = true;
                        // hitPos = lerp(traceLocalStart, hitPos, f);
                        opaque_color = texSource.Sample(sub_screenPos);
                        break;
                    }
                }
            }

            if (!ss_hit) {
                if (hit) {
                    float3 hitNormal = -stepAxis * sign(refract_localDir);
                    float3 hit_viewPos = mul3(ap.camera.view, hitPos);
                    float3 hit_screenPos = project(ap.camera.projection, hit_viewPos) * 0.5 + 0.5;
                    float hit_depth = solidDepthTex.Sample(hit_screenPos.xy);
                    // if (all(saturate(hit_screenPos) == hit_screenPos) && abs(hit_depth - hit_screenPos.z) < 0.00008) {
                    //     opaque_color = texSource.Sample(hit_screenPos.xy);
                    // }
                    // else {
                        // float3 voxelTex_pos = VoxelTex_GetBufferPosition(hitPos);
                        // int3 voxelTex_coord = int3(floor(voxelTex_pos));

                        if (VoxelTex_InBounds(hitVoxelTexPos)) {
                            uint2 uv_min, uv_size;
                            uint voxelTex_data = texVoxelTexId[hitVoxelTexPos];
                            VoxelTex_unpack(voxelTex_data, uv_min, uv_size);

                            // if (voxelTex_data > 0) opaque_color = 0.0;

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

                            if (voxelTex_data == 0)
                                opaque_color = float3(1,0,0);
                        }

                        // TODO: rebuild lighting sample
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
                    // }
                }
                else {
                    opaque_color = sampleSkyFinal(hitPos, refract_localDir, false);
                }
            }

            opaque_color *= half3(exp(-traceWaterDist * Water_AbsorbColor));
            // opaque_color *= traceTint;
        }
    }

    uint2 refract_uv = uint2(refract_texcoord * ap.game.screenSize);

    // if (hasRefract && waterDist > transDist) {
    //     water_uv = refract_uv;
    //     waterDist = WaterDepth_get(refract_uv);
    // }

    // if (hasRefract && transDist > waterDist && translucent.a > 0.0) {
    //     // WARN: causes fuckery
    //     // float transDepth = mainDepthTex[refract_uv];
    //     translucent = texFinalTranslucent[refract_uv];
    //     tint = texTintTranslucent[refract_uv];

    //     // TODO: update trans pos/dist?
    // }

    half4 waterColor = texWaterFinal[water_uv];

    opaqueViewPos = transViewPos;
    if (hasRefract && all(refract_texcoord >= 0.0)) {
        // float opaqueDepth = solidDepthTex.Sample(refract_texcoord);
        float3 opaqueClipPos = float3(refract_texcoord, opaqueDepth) * 2.0 - 1.0;
        opaqueViewPos = project(ap.camera.projectionInv, opaqueClipPos);
        // float3 localPos = mul3(ap.camera.viewInv, viewPos);

        // opaque_color = texSource.Sample(refract_texcoord);

        if (waterDist > transDist)
            waterColor.rgb *= tint;
    }

    if (translucent.a > 0.0)
        opaque_color *= tint;

    float opaqueDist = length(opaqueViewPos);

    float waterMin, waterMax;
    if (ap.camera.fluid == 1) {
        waterMin = 0.0;
        waterMax = min(waterDist, opaqueDist);
    }
    else {
        waterMin = waterDist;
        waterMax = min(ap.camera.far, opaqueDist);
    }

    float waterDepthL = max(waterMax - waterMin, 0.0);

    float opaqueWaterDepthL = max(waterMax - waterMin, 0.0);
    half3 opaqueWaterTint = half3(exp(-(waterDepthL + EPSILON) * Water_AbsorbColor));

    if (ap.camera.fluid == 0 && waterDepthL > 0.0) {
        opaque_color += fma(opaque_color, half3(1.0 - waterColor.a), waterColor.rgb);
    }

    half3 final_color = fma(opaque_color, half3(1.0 - translucent.a), translucent.rgb);

    if (ap.camera.fluid == 0 && translucent.a > 0.0 && transDist > waterDist) {
        // tint translucent under water
        float transWaterDist = max(transDist - waterDist, EPSILON);
        half3 transWaterTint = half3(exp(-transWaterDist * Water_AbsorbColor));
        final_color *= transWaterTint;
    }

    if (ap.camera.fluid == 1 || (translucent.a > 0.0 && transDist > waterDist))
        final_color = fma(final_color, half3(1.0 - waterColor.a), waterColor.rgb);

    if (ap.camera.fluid == 1) {
        final_color *= opaqueWaterTint;
    }
    
    final_color.rgb += weather.rgb * half3(0.25);

    return half4(final_color, half2(1.0).x);
}
