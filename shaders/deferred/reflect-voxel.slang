import aperture;
import buffers.ObjectData;
import lib.common;
import lib.material.pbr;
import lib.material.rough_normal;
import lib.light.fresnel;
import lib.sampling.atlas;
import lib.sampling.depth;
import lib.sampling.IGN;
import lib.shadow;
import lib.sky.common;
import lib.sky.sample_transmit;
import lib.sky.sample_irradiance;
import lib.sky.sample_final;
import lib.voxel_tex;
import lib.dda;

extern static const bool Reflect_SS_Fallback = false;
// extern static const bool Debug_WhiteWorld;
extern static const bool World_HasSky;
extern static const uint BLOCK_WATER;

StructuredBuffer<uint2> voxelTexBuffer;

Sampler2D<float> solidDepthTex;
Sampler2D<half3> texSource;

Sampler2D<half4> texAlbedoGB;
Sampler2D<uint2> texNormalGB;
Sampler2D<uint2> texMatLightGB;

Sampler2D<half3> blockAtlas;


[[shader("fragment")]]
half4 applyReflections(float2 pos : SV_Position) : SV_Target0 {
    uint2 uv = uint2(pos);
    float depth = solidDepthTex[uv];
    half3 finalColor = texSource[uv];
    
    if (depth < 1.0) {
        float2 texcoord = pos / ap.game.screenSize;
        if (TAA_Enabled) texcoord -= scene[0].taa_jitter;

        float3 screenPos = float3(texcoord, depth);
        float3 clipPos = screenPos * 2.0 - 1.0;
        float3 viewPos = project(ap.camera.projectionInv, clipPos);
        float3 localPos = mul3(ap.camera.viewInv, viewPos);

        half4 colorData = texAlbedoGB[uv];

        half3 tex_normal = ObjectData_Normals.unpackTex(texNormalGB[uv].g);

        ObjectData_MatLit mat_lit;
        mat_lit.unpack(texMatLightGB[uv]);

        half3 albedo = RgbToLinear(colorData.rgb);
        half roughness = mat_roughness(mat_lit.specular.r);
        half f0_metal = mat_f0_metal(mat_lit.specular.g);
        half metalness = (half)mat_metalness(f0_metal);

        half lmcoord_y = pow2(mat_lit.lmcoord.y);
        half roughL = pow2(roughness);

        float dither = InterleavedGradientNoiseTime(pos);

        // get reflection direction
        float3 roughNormal = randomizeNormal(uv, tex_normal, roughL);
        
        float viewDist = length(viewPos);
        float3 viewDir = viewPos / viewDist;
        float3 viewNormal = mul(float3x3(ap.camera.view), roughNormal);
        float3 reflect_viewDir = reflect(viewDir, viewNormal);
        float3 reflect_localDir = mul(float3x3(ap.camera.viewInv), reflect_viewDir);



        float3 cameraFract = fract(ap.camera.position);
        int3 cameraFloor = int3(floor(ap.camera.position));

        float3 stepSizes, nextDist, stepAxis;
        // float3 traceLocalStart = localPos;
        float3 localDir = normalize(localPos);
        float3 currPos = localPos + cameraFract - localDir*0.02;
        dda_init(stepSizes, nextDist, currPos, reflect_localDir);

        bool hit = false;
        float traceWaterDist = EPSILON;
        int3 hit_voxelTexPos = -1;
        int3 hit_voxelPos = 0;
        float3 hit_localPos;

        for (uint i = 0; i < 64; i++) {
            float3 stepAxisNext;
            float3 step = dda_step(stepAxisNext, nextDist, stepSizes, reflect_localDir);

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

                float sampleClipDepth = solidDepthTex.Sample(traceScreenPos) * 2.0 - 1.0;
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

                // traceDepthL_prev = linearizeDepth(traceClipStart.z, ap.camera.near, ap.camera.far);
                for (uint i = 0; i < SS_RefineSteps; i++) {
                    float f = (i + dither) / SS_RefineSteps;
                    traceClipPos = lerp(traceClipStart, traceClipEnd, f);
                    traceScreenPos = traceClipPos.xy * 0.5 + 0.5;
                    if (!all(saturate(traceScreenPos) == traceScreenPos)) break;

                    float sampleClipDepth = solidDepthTex.Sample(traceScreenPos) * 2.0 - 1.0;
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
                float3 hitNormal = -stepAxis * sign(reflect_localDir);
                float3 hit_viewPos = mul3(ap.camera.view, hit_localPos);
                float3 hit_screenPos = project(ap.camera.projection, hit_viewPos) * 0.5 + 0.5;
                float hit_depth = solidDepthTex.Sample(hit_screenPos.xy);

                if (VoxelTex_InBounds(hit_voxelTexPos)) {
                    // uint2 uv_min, uv_size;
                    // uint voxelTex_data = texVoxelTexId[hit_voxelTexPos];
                    // VoxelTex_unpack(voxelTex_data, uv_min, uv_size);

                    VoxelTex voxel;
                    uint voxelIndex = VoxelTex_GetBufferIndex(hit_voxelTexPos);
                    voxel.unpack(voxelTexBuffer[voxelIndex]);

                    float2 hitCoord;
                    if (abs(hitNormal.y) > 0.5)      hitCoord = currPos.xz;
                    else if (abs(hitNormal.z) > 0.5) hitCoord = currPos.xy;
                    else                             hitCoord = currPos.zy;
                    hitCoord = 1.0 - fract(hitCoord);

                    uint3 atlasSize;
                    blockAtlas.GetDimensions(0, atlasSize.x, atlasSize.y, atlasSize.z);

                    AtlasBounds atlas;
                    atlas.CoordMin = voxel.uv_min / float2(atlasSize.xy);
                    atlas.CoordSize = voxel.uv_size / float2(atlasSize.xy);
                    float2 uv = atlas.GetAtlasCoord(hitCoord);

                    reflectColor = blockAtlas.Sample(uv).rgb * voxel.tint;
                    reflectColor = RgbToLinear(reflectColor);

                    if (voxelTexBuffer[voxelIndex].r == 0) {
                        // debug missing data with red albedo
                        reflectColor = half3(0.0);// half3(1, 0, 0);
                    }
                }

                half3 diffuse = half3(0.0);
                float3 skyPos = getSkyPosition(hit_localPos);

                float3 shadowLocalPos = hitNormal * 0.04 + hit_localPos;
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

                var hitVoxel = ap.voxel[hit_voxelPos];
                float lmcoord_y = 1.0; //saturate(hitVoxel.lightData.y / 15.0);
                float3 sky_ambient = sampleSkyIrradiance(hitNormal) * lmcoord_y;// * occlusion;

                reflectColor *= diffuse / PI + sky_ambient;
            }
            else {
                reflectColor = sampleSkyFinal(hit_localPos, reflect_localDir, false);
            }
        }

        half3 f0 = lerp(half3(f0_metal), albedo.rgb, metalness);

        // half3 localDir = half3(normalize(localPos));
        half NoVm = max(dot(tex_normal, -localDir), (half)0.0);
        half3 F_NoV = F_schlickRough(NoVm, f0, roughL);
        half3 specular_tint = lerp((half)1.0, albedo, metalness);

        // imgDebug[uv] = float4(LinearToRgb(reflectColor * 0.008), 1.0);

        finalColor += F_NoV * ((half)1.0 - roughL) * reflectColor * specular_tint;
    }

    return half4(finalColor, (half)1.0);
}
