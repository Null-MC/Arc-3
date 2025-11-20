import aperture;
import buffers.ObjectData;
import lib.common;
import lib.material.pbr;
import lib.light.brdf;
import lib.light.fresnel;
import lib.sampling.depth;
import lib.water.wetness;
import lib.hsv;

extern static const int PointLight_MaxCount;
extern static const bool DEBUG_LIGHT_TILES;

static const uint groupResX = 16;
static const uint groupResY = 16;

static const uint sharedBufferResX = groupResX+2;
static const uint sharedBufferResY = groupResY+2;
static const uint sharedBufferSize = sharedBufferResX*sharedBufferResY;
groupshared uint sharedLightList[256];
groupshared Atomic<uint> depthMinInt, depthMaxInt;
groupshared Atomic<uint> counter;

[[vk::image_format("rgba16f")]]
RWTexture2D<half3> imgDiffuse;

[[vk::image_format("rgba16f")]]
RWTexture2D<half3> imgSpecular;

Sampler2D<float> texDepth;
Sampler2D<half2> texWetnessGB;

Sampler2D<half4> texAlbedoGB;
Sampler2D<uint2> texNormalGB;
Sampler2D<uint2> texMatLightGB;

SamplerCubeArrayShadow pointLightFiltered;


// float4 projectSphereView(float3 center, float radius, float P00, float P11) {
//     float3 cr = center * radius;
//     float czr2 = center.z * center.z - radius * radius;
//     float2 v = sqrt(center.xy * center.xy + czr2);

//     float minx = (v.x * center.x - cr.z) / (v.x * center.z + cr.x);
//     float maxx = (v.x * center.x + cr.z) / (v.x * center.z - cr.x);

//     float miny = (v.y * center.y - cr.z) / (v.y * center.z + cr.y);
//     float maxy = (v.y * center.y + cr.z) / (v.y * center.z - cr.y);

//     float4 aabb = float4(minx * P00, miny * P11, maxx * P00, maxy * P11);
//     // clip space -> uv space
//     aabb = aabb * float4(0.5f, -0.5f, 0.5f, -0.5f) + float4(0.5f);

//     return aabb;
// }

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
[numthreads(16, 16, 1)]
void applyPointLights(ComputeInput input) {
    if (input.groupIndex == 0) {
        depthMinInt = uint.maxValue;
        depthMaxInt = uint.minValue;
        counter = 0;
    }

    GroupMemoryBarrierWithGroupSync();

    uint2 uv = input.globalPos.xy;
    bool on_screen = all(uv < ap.game.screenSize);
    half4 colorData;
    float depth;

    if (on_screen) {
        depth = texDepth[uv];
        colorData = texAlbedoGB[uv];

        if (depth < 1.0 && colorData.a > 0.0) {
            float depthL = linearizeDepth(depth * 2.0 - 1.0, ap.camera.near, ap.camera.far);
            float depthInt = depthL / ap.camera.far * uint.maxValue;
            depthMinInt.min(uint(floor(depthInt)));
            depthMaxInt.max(uint(ceil(depthInt)));
        }
    }

    GroupMemoryBarrierWithGroupSync();

    float depthMin = depthMinInt.load() / float(uint.maxValue) * ap.camera.far;
    float depthMax = depthMaxInt.load() / float(uint.maxValue) * ap.camera.far;

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
            uint2 groupPos = input.groupPos.xy * WorkgroupSize().xy;
            float2 groupPosMin = groupPos / float2(ap.game.screenSize);
            float2 groupPosMax = (groupPos + WorkgroupSize().xy) / float2(ap.game.screenSize);
            
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

    if (!on_screen) return;

    half3 src_diffuse = imgDiffuse[input.globalPos.xy].rgb;
    half3 src_specular = imgSpecular[input.globalPos.xy].rgb;
    uint total = counter.load();

    float3 diffuse = 0.0;
    float3 specular = 0.0;

    if (depth < 1.0 && colorData.a > 0.0 && total > 0) {
        ObjectData_Normals normals;
        normals.unpack(texNormalGB[uv]);

        ObjectData_MatLit mat_lit;
        mat_lit.unpackSpecular(texMatLightGB[uv].r);

        float2 texcoord = (input.globalPos.xy + 0.5) / float2(ap.game.screenSize);
        if (TAA_Enabled) texcoord -= scene[0].taa_jitter;

        float3 clipPos = float3(texcoord, depth) * 2.0 - 1.0;
        float3 viewPos = project(ap.camera.projectionInv, clipPos);
        float3 localPos = mul3(ap.camera.viewInv, viewPos);

        float3 viewDir = -normalize(localPos);

        half roughness = mat_roughness(mat_lit.specular.r);
        half f0_metal = mat_f0_metal(mat_lit.specular.g);
        half sss = mat_sss(mat_lit.specular.b);

        half2 wetness_puddle = texWetnessGB[uv];
        Wetness_ApplyRoughness(roughness, wetness_puddle.x);
        Wetness_ApplyNormal(normals.tex, normals.geo, wetness_puddle.y);

        half3 albedo = RgbToLinear(colorData.rgb);
        half roughL = roughness * roughness;

        const float offsetBias = lerp(0.06, 0.24, sss);
        const float normalBias = 0.12;
        float3 localSamplePos = normalBias * normals.geo + localPos;

        float NoVm = max(dot(normals.tex, viewDir), 0.0);
        // float3 f0 = f0_metal < 0.9 ? f0_metal : albedo;
        half metalness = mat_metalness(f0_metal);
        half3 f0 = lerp(f0_metal, albedo, metalness);

        for (uint i = 0; i < total; i++) {
            uint lightIndex = sharedLightList[i];
            PointLight light = ap.lights[lightIndex];
            half4 lightColor = half4(ap.blocks[light.block].lightColor);
            half lightRange = (half)ap.blocks[light.block].emission;

            float3 lightOffset = light.position - localSamplePos;

            half lightDist = (half)length(lightOffset);
            float3 lightDir = lightOffset / lightDist;

            const half lightRadius = clamp(lightColor.a, EPSILON, 1.0) * 0.5;// (half)0.5; // TODO: build a LUT for this
            half lightAtt = GetLightAttenuation(lightDist, lightRange, lightRadius);
            if (lightAtt < EPSILON) continue;

            lightColor.rgb = RgbToLinear(lightColor.rgb);
            lightColor *= saturate(lightRange / (half)15.0) * BLOCK_LUX;

            float NoL = dot(normals.tex, lightDir);
            float NoLm = max(NoL, 0.0);

            float sss_wrap = pow2(sss);
            float NoLm_wrap = max((NoL + sss_wrap) / (1.0 + sss_wrap), 0.0);

            float3 H = normalize(lightDir + viewDir);
            float NoHm = max(dot(normals.tex, H), 0.0);
            float LoHm = max(dot(lightDir, H), 0.0);
            float VoHm = max(dot(viewDir, H), 0.0);

            float shadowDepth = unmix(ap.lights.nearPlane, ap.lights.farPlane, lightDist - offsetBias);
            half shadow = (half)pointLightFiltered.SampleCmp(float4(-lightDir, lightIndex), shadowDepth).r;
            lightColor *= shadow * NoLm_wrap * lightAtt;

            //float3 F_VoH = material_fresnel(albedo, f0_metal, roughL, VoHm);
            half3 F_VoH = F_schlickRough(VoHm, f0, roughL);
            
            diffuse += lightColor.rgb * SampleLightDiffuse(NoVm, NoLm_wrap, LoHm, roughL) * saturate((half)1.0 - F_VoH);
            specular += lightColor.rgb * SampleLightSpecular(NoLm, NoHm, NoVm, F_VoH, roughL);
        }

        diffuse /= half3(PI);
    }

    if (DEBUG_LIGHT_TILES) {
        float hue = lerp(0.65, 0.0, total / 256.0);
        half3 debug_color = HsvToRgb(float3(hue, 1.0, 1.0));
        imgDebug[input.globalPos.xy] = half4(debug_color, (half)1.0);
    }

    imgDiffuse[input.globalPos.xy] = src_diffuse + diffuse;
    imgSpecular[input.globalPos.xy] = src_specular + specular;
}
