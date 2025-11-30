import aperture;
import lib.common;
import lib.noise.hash;
import lib.sampling.depth;
import lib.light.brdf;
import lib.light.floodfill;
import lib.light.shadow;
import lib.water.common;
import lib.voxel.froxel;
import lib.sky.common;
import lib.sky.density;
import lib.sky.scattering;
import lib.sky.sample_transmit;
import lib.sky.sample_multiscatter;


extern static const int Froxel_MaxFrames = 15;
extern static const uint Froxel_SkyLight_StepCount = 8;
extern static const float Froxel_SkyLight_TraceDist = 16.0;
extern static const uint Froxel_PointLight_StepCount = 4;
extern static const bool FloodFill_Enabled;
extern static const bool PointLight_Enabled;
extern static const int PointLight_MaxCount;

groupshared uint sharedLightList[PointLight_MaxCount];
groupshared Atomic<uint> counter;

[[vk::image_format("rgba16f")]]
RWTexture3D<half4> imgFroxel_write;

Sampler2D<float> texDepth;
Sampler3D<half4> texFroxel_read;
SamplerCubeArrayShadow pointLightFiltered;


float3 unprojectCorner(const in float screenPosX, const in float screenPosY) {
    float3 ndcPos = float3(screenPosX, screenPosY, 1.0) * 2.0 - 1.0;
    return project(ap.camera.projectionInv, ndcPos);
}

bool LightCollisionTest(const in uint3 groupPos, const in uint lightIndex) {
    PointLight light = ap.lights[lightIndex];
    if (light.block < 0) return false;

    half lightRange = (half)ap.blocks[light.block].emission + (half)0.5;

    // compute view-space position and collision test
    float3 lightViewPos = mul3(ap.camera.view, light.position);

    uint3 groupPosBase = groupPos * WorkgroupSize();
    float3 groupPosMin = groupPosBase / float3(Froxel_Resolution);
    float3 groupPosMax = (groupPosBase + WorkgroupSize()) / float3(Froxel_Resolution);

    float depthMin = pow2(groupPosMin.z) * Froxel_MaxDist;
    float depthMax = pow2(groupPosMax.z) * Froxel_MaxDist;

    bool hit = true;
    if (-lightViewPos.z + lightRange < depthMin) hit = false;
    if (-lightViewPos.z - lightRange > depthMax) hit = false;

    // test X/Y
    float3 c1 = unprojectCorner(groupPosMin.x, groupPosMin.y);
    float3 c2 = unprojectCorner(groupPosMax.x, groupPosMin.y);
    float3 c3 = unprojectCorner(groupPosMin.x, groupPosMax.y);
    float3 c4 = unprojectCorner(groupPosMax.x, groupPosMax.y);

    float3 clipDown  = normalize(cross(c2, c1));
    float3 clipRight = normalize(cross(c4, c2));
    float3 clipUp    = normalize(cross(c3, c4));
    float3 clipLeft  = normalize(cross(c1, c3));
    
    if (dot(clipDown,  lightViewPos) > lightRange) hit = false;
    if (dot(clipRight, lightViewPos) > lightRange) hit = false;
    if (dot(clipUp,    lightViewPos) > lightRange) hit = false;
    if (dot(clipLeft,  lightViewPos) > lightRange) hit = false;

    return hit;
}

float3 SamplePointLight(const in uint lightIndex, const in float3 localPos, const in float3 localDir, const in float extinction, const in float dither) {
    PointLight light = ap.lights[lightIndex];
    half4 lightColor = half4(ap.blocks[light.block].lightColor);
    half lightRange = (half)ap.blocks[light.block].emission;

    float3 lightOffset = light.position - localPos;
    half lightDist = (half)length(lightOffset);
    float3 lightDir = lightOffset / lightDist;

    half lightRadius = clamp(lightColor.a, EPSILON, 1.0) * 0.5;
    half lightAtt = GetLightAttenuation(lightDist, lightRange, lightRadius);
    if (lightAtt < EPSILON) return 0.0;

    lightColor.rgb = RgbToLinear(lightColor.rgb);
    lightColor.rgb *= saturate(lightRange / (half)15.0) * BLOCK_LUX;

    float light_VoL = dot(localDir, lightDir);
    float lightPhase = max(getMiePhase(light_VoL), 0.0);

    float shadowDepth = saturate(unmix(ap.lights.nearPlane, ap.lights.farPlane, lightDist));
    half shadow = (half)pointLightFiltered.SampleCmp(float4(-lightDir, lightIndex), shadowDepth).r;
    lightColor.rgb *= lightPhase * shadow * lightAtt;

    if (Sky_FogNoise) {
        float stepDist = lightDist / Froxel_PointLight_StepCount;
        float accumDensity = 0.0;

        for (uint i = 0; i < Froxel_PointLight_StepCount; i++) {
            float stepF = (i + dither) / Froxel_PointLight_StepCount;
            // float3 trace_localPos = lerp(localPos, light.position, stepF);
            float3 trace_localPos = localPos + stepF * lightOffset;

            accumDensity += SampleFogDensity(trace_localPos) * stepDist;
        }
        
        lightColor.rgb *= exp(-max(extinction * accumDensity, EPSILON));
    }
    else {
        lightColor.rgb *= exp(-max(extinction * lightDist, EPSILON));
    }

    return lightColor.rgb;
}


struct ComputeInput {
    uint groupIndex : SV_GroupIndex;
    uint3 groupPos : SV_GroupID;
    uint3 localPos : SV_GroupThreadID;
    uint3 globalPos : SV_DispatchThreadID;
};

[[shader("compute")]]
[numthreads(8, 8, 4)]
void updateFroxels(ComputeInput input) {
	if (any(input.globalPos >= Froxel_Resolution)) return;

    float3 seed = input.globalPos + float3(3,9,13)*ap.timing.frameCounter;
    float3 bufferPos = input.globalPos + hash33(seed);

    float3 ndcPos = Froxel_GetNdcPosition(bufferPos);
    float3 localPos = project(scene[0].viewProjectionInv, ndcPos);
    float3 localDir = normalize(localPos);

    float dither = hash13(seed);

    bool isWater = ap.voxel[int3(floor(localPos + ap.camera.position))].block.isFluid;

    float3 scatter = 0.0;
    float transmit = 1.0;

    if (World_HasSky) {
        float3 skyPos = getSkyPosition(localPos);
        bool shadowIsSun = dot(ap.celestial.position, ap.celestial.sunPosition) > 0.0;

        half3 sun_color = scene[0].SunColor * sampleSkyTransmit(skyPos, scene[0].SunLocalDir);
        half3 moon_color = scene[0].MoonColor * sampleSkyTransmit(skyPos, scene[0].MoonLocalDir);
        float3 skyLight = shadowIsSun ? sun_color : moon_color;

        float3 shadowViewPos = mul3(ap.celestial.view, localPos);
        int shadowCascade = GetShadowProjection(shadowViewPos, 0.0);

        if (shadowCascade >= 0) {
            float3 shadowPos = mul3(ap.celestial.projection[shadowCascade], shadowViewPos);
            // skyLight *= SampleShadowColor(shadowPos * 0.5 + 0.5, shadowCascade);
            shadowPos = shadowPos * 0.5 + 0.5;

            // TODO: shadow water depth?
            float3 shadowCoord = float3(shadowPos.xy, shadowCascade);
            float depthOpaque = solidShadowMap.Sample(shadowCoord);

            half3 shadow;
            if (shadowPos.z > depthOpaque) shadow = half3(0.0);
            else {
                float depthTrans = shadowMap.Sample(shadowCoord);

                if (shadowPos.z + EPSILON <= depthTrans) shadow = half3(1.0);
                else {
                    shadow = texShadowColor.Sample(shadowCoord);
                    shadow = RgbToLinear(shadow);

                    // TODO: don't use camera check, causes noticeable transition
                    // bool isWater = true;//ap.camera.fluid == 1;

                    if (isWater) {
                        // float scale = GetShadowProjectionScale(shadowCascade).z;
                        float scale = (-2.0 / ap.celestial.projection[shadowCascade][2][2]);
                        float waterDepth = max(shadowPos.z - depthTrans, 0.0) * scale;
                        if (waterDepth > 0.0) shadow *= exp(-waterDepth * Water_AbsorbColor);
                    }
                }
            }

            skyLight *= shadow;
        }

        float3 skyTrace_localEnd = localPos + scene[0].SkyLightLocalDir * Froxel_SkyLight_TraceDist;
        float skyTrace_stepDist = Froxel_SkyLight_TraceDist / Froxel_SkyLight_StepCount;
        float accumDensity = 0.0;

        for (uint i = 0; i < Froxel_SkyLight_StepCount; i++) {
            float stepF = (i + dither) / Froxel_SkyLight_StepCount;
            float3 trace_localPos = lerp(localPos, skyTrace_localEnd, stepF);

            accumDensity += SampleFogDensity(trace_localPos) * skyTrace_stepDist;
        }
        
        if (accumDensity > EPSILON) {
            float extinction = accumDensity * 0.001 * (scene[0].sky.mieScatteringBase + scene[0].sky.mieAbsorptionBase);
            skyLight *= exp(-extinction);
        }

        float3 ambient = 0.0;
        // if (ap.camera.fluid != 1)
            ambient += sampleSkyMultiScatter(skyPos, scene[0].SunLocalDir);
        // ambient = ambient * ap.camera.BrightnessSmooth; + VL_MinLight;
        if (isWater) ambient *= 0.2;

        float sky_VoL = dot(localDir, scene[0].SkyLightLocalDir);
        float miePhase_sky = max(getMiePhase(sky_VoL, 0.2), 0.0);
        scatter += miePhase_sky * skyLight + ambient;
    }

    if (PointLight_Enabled) {
        if (input.groupIndex == 0) {
            counter = 0;
        }

        GroupMemoryBarrierWithGroupSync();

        uint2 uv = input.globalPos.xy;
        bool on_screen = all(uv < Froxel_Resolution.xy);

        if (input.groupIndex < PointLight_MaxCount) {
            if (LightCollisionTest(input.groupPos, input.groupIndex)) {
                uint index = counter.increment();
                sharedLightList[index] = input.groupIndex;
            }
        }

        GroupMemoryBarrierWithGroupSync();

        uint total = counter.load();

        if (on_screen && total > 0) {
            float extinction_base = 0.001 * (scene[0].sky.mieScatteringBase + scene[0].sky.mieAbsorptionBase);

            // premultiply density when noise is disabled
            if (!Sky_FogNoise) extinction_base *= SampleFogDensity(localPos);
            
            for (uint i = 0; i < total; i++) {
                uint lightIndex = sharedLightList[i];
                scatter += SamplePointLight(lightIndex, localPos, localDir, extinction_base, dither);
            }
        }
    }

    if (FloodFill_Enabled) {
        float3 lpvPos = FloodFill_GetBufferPosition(localPos);
        
        if (FloodFill_InBounds(lpvPos)) {
            scatter += floodfill_sample(lpvPos) * BLOCK_LUX * phaseIso;
        }
    }

    scatter *= isWater
        ? Water_ScatterColor
        : 0.001 * scene[0].sky.mieScatteringBase;

    // project last frame position and accumulate
    float3 bufferPosLast = input.globalPos + 0.5;
    float3 ndcPosLast = Froxel_GetNdcPosition(bufferPosLast);
    float3 localPosLast = project(scene[0].viewProjectionInv, ndcPosLast);

    localPosLast += (ap.camera.position - ap.temporal.position);

    ndcPosLast = project(scene[0].viewProjectionLast, localPosLast);
    bufferPosLast = Froxel_GetBufferPosition(ndcPosLast);

    half4 froxelPrev = half4(0.0);
    if (Froxel_InBufferBounds(bufferPosLast)) {
        froxelPrev = texFroxel_read.Sample(bufferPosLast / Froxel_Resolution);
    }

    half counter = (half)clamp(froxelPrev.a + 1.0, 1.0, Froxel_MaxFrames);
    half3 final = (half3)lerp(froxelPrev.rgb, scatter, rcp(counter));

    imgFroxel_write[input.globalPos] = half4(final, counter);
}
