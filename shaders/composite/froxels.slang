import aperture;
import lib.common;
import lib.shadow;
import lib.voxel.froxel;
import lib.light.brdf;
import lib.light.floodfill;
import lib.sampling.depth;
import lib.noise.hash;
import lib.sky.common;
import lib.sky.scattering;
import lib.sky.sample_transmit;


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

    float3 bufferPos = input.globalPos + hash33(input.globalPos + float3(3,9,13)*ap.timing.frameCounter);

    float3 ndcPos = Froxel_GetNdcPosition(bufferPos);
    float3 viewPos = project(ap.camera.projectionInv, ndcPos);
    float3 localPos = mul3(ap.camera.viewInv, viewPos);
    float3 localDir = normalize(localPos);

    float3 scatter = 0.0;
    float transmit = 1.0;

    if (World_HasSky) {
        float3 shadowViewPos = mul3(ap.celestial.view, localPos);

        int shadowCascade = GetShadowProjection(shadowViewPos, 0.0);

        half3 shadow = half3(1.0);
        if (shadowCascade >= 0) {
            float3 shadowPos = mul3(ap.celestial.projection[shadowCascade], shadowViewPos);
            shadow = SampleShadowColor(shadowPos * 0.5 + 0.5, shadowCascade);
        }

        float3 skyPos = getSkyPosition(localPos);
        bool shadowIsSun = dot(ap.celestial.position, ap.celestial.sunPosition) > 0.0;

        half3 sun_color = scene[0].SunColor * sampleSkyTransmit(skyPos, scene[0].SunLocalDir);
        sun_color *= atmosAbsorb(skyPos, scene[0].SunLocalDir);

        half3 moon_color = scene[0].MoonColor * sampleSkyTransmit(skyPos, scene[0].MoonLocalDir);
        moon_color *= atmosAbsorb(skyPos, scene[0].MoonLocalDir);

        float VoL = dot(localDir, scene[0].SkyLightLocalDir);
        float sky_phase = max(getMiePhase(VoL), 0.0);

        scatter += sky_phase * (shadowIsSun ? sun_color : moon_color) * shadow;
    }

    if (PointLight_Enabled) {
        if (input.groupIndex == 0) {
            counter = 0;
        }

        GroupMemoryBarrierWithGroupSync();

        uint2 uv = input.globalPos.xy;
        bool on_screen = all(uv < Froxel_Resolution.xy);

        uint3 groupPos = input.groupPos * WorkgroupSize();
        float3 groupPosMin = groupPos / float3(Froxel_Resolution);
        float3 groupPosMax = (groupPos + WorkgroupSize()) / float3(Froxel_Resolution);

        float depthMin = pow2(groupPosMin.z) * Froxel_MaxDist;
        float depthMax = pow2(groupPosMax.z) * Froxel_MaxDist;

        if (input.groupIndex < PointLight_MaxCount) {
            PointLight light = ap.lights[input.groupIndex];

            if (light.block >= 0) {
                half lightRange = (half)ap.blocks[light.block].emission + (half)0.5;

                // compute view-space position and collision test
                float3 lightViewPos = mul3(ap.camera.view, light.position);
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

                if (hit) {
                    uint index = counter.increment();
                    sharedLightList[index] = input.groupIndex;
                }
            }
        }

        GroupMemoryBarrierWithGroupSync();

        uint total = counter.load();

        if (on_screen && total > 0) {
            for (uint i = 0; i < total; i++) {
                uint lightIndex = sharedLightList[i];
                PointLight light = ap.lights[lightIndex];
                half4 lightColor = half4(ap.blocks[light.block].lightColor);
                half lightRange = (half)ap.blocks[light.block].emission;

                float3 lightOffset = light.position - localPos;
                half lightDist = (half)length(lightOffset);
                float3 lightDir = lightOffset / lightDist;

                half lightRadius = clamp(lightColor.a, EPSILON, 1.0) * 0.5;
                half lightAtt = GetLightAttenuation(lightDist, lightRange, lightRadius);
                if (lightAtt < EPSILON) continue;

                lightColor.rgb = RgbToLinear(lightColor.rgb);
                lightColor.rgb *= saturate(lightRange / (half)15.0) * BLOCK_LUX;

                float light_VoL = dot(localDir, lightDir);
                float lightPhase = max(getMiePhase(light_VoL), 0.0);

                float shadowDepth = saturate(unmix(ap.lights.nearPlane, ap.lights.farPlane, lightDist));
                half shadow = (half)pointLightFiltered.SampleCmp(float4(-lightDir, lightIndex), shadowDepth).r;
                lightColor.rgb *= lightPhase * shadow * lightAtt;

                // TODO: More
                scatter += lightColor.rgb;
            }
        }
    }

    if (FloodFill_Enabled) {
        float3 lpvPos = FloodFill_GetBufferPosition(localPos);
        
        if (FloodFill_InBounds(lpvPos)) {
            scatter += floodfill_sample(lpvPos) * BLOCK_LUX * phaseIso;
        }
    }

    // project last frame position and accumulate
    float3 bufferPosLast = input.globalPos + 0.5;
    float3 ndcPosLast = Froxel_GetNdcPosition(bufferPosLast);
    float3 viewPosLast = project(ap.camera.projectionInv, ndcPosLast);
    float3 localPosLast = mul3(ap.camera.viewInv, viewPosLast);

    localPosLast += (ap.camera.position - ap.temporal.position);

    viewPosLast = mul3(ap.temporal.view, localPosLast);
    ndcPosLast = project(ap.temporal.projection, viewPosLast);
    bufferPosLast = Froxel_GetBufferPosition(ndcPosLast);

    half4 froxelPrev = 0.0;
    if (Froxel_InBufferBounds(bufferPosLast)) {
        froxelPrev = texFroxel_read.Sample(bufferPosLast / Froxel_Resolution);
    }

    float counter = clamp(froxelPrev.a + 1.0, 1.0, 30.0);
    float3 final = lerp(froxelPrev.rgb, scatter, rcp(counter));

    imgFroxel_write[input.globalPos] = (half4)float4(final, counter);
}
