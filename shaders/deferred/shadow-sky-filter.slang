import aperture;
import lib.common;
import lib.sampling.depth;
import lib.sampling.gaussian;

static const uint groupResX = 16;
static const uint groupResY = 16;
static const int sharedBufferResX = groupResX+4;
static const int sharedBufferResY = groupResY+4;
static const int sharedBufferSize = sharedBufferResX*sharedBufferResY;

static const float g_sigmaXY = 6.0;
static const float g_sigmaV = 0.008;

groupshared half sharedGaussian[5];
groupshared half3 sharedShadow[sharedBufferSize];
groupshared half3 sharedSss[sharedBufferSize];
groupshared float sharedDepth[sharedBufferSize];

[[vk::image_format("rgba8")]]
RWTexture2D<half3> imgShadowFinal;

[[vk::image_format("rgba8")]]
RWTexture2D<half3> imgSssFinal;

Sampler2D<float> texDepth;
Sampler2D<half3> texShadowGB;
Sampler2D<half3> texSssGB;


void sampleSharedBuffer(const in uint2 uv_base, const in float depthL, out half3 shadow, out half3 sss) {
    half total = (half)0.0;
    half3 accum_shadow = half3(0.0);
    half3 accum_sss = half3(0.0);
    
    for (int iy = 0; iy < 5; iy++) {
        half fy = sharedGaussian[iy];

        for (int ix = 0; ix < 5; ix++) {
            half fx = sharedGaussian[ix];
            
            int2 uv_shared = uv_base + (int2(ix, iy) - 2);
            int i_shared = uv_shared.y * sharedBufferResX + uv_shared.x;

            half3 sample_shadow = sharedShadow[i_shared];
            half3 sample_sss = sharedSss[i_shared];
            float sampleDepthL = sharedDepth[i_shared];
            
            half depthDiff = (half)abs(sampleDepthL - depthL);
            half fv = half(Gaussian(g_sigmaV, depthDiff));
            
            half weight = fx*fy*fv;
            accum_shadow += weight * sample_shadow;
            accum_sss += weight * sample_sss;
            total += weight;
        }
    }
    
    //if (total <= EPSILON) return float4(float3(1.0), 0.0);
    shadow = accum_shadow / total;
    sss = accum_sss / total;
}


struct ComputeInput {
    uint groupIndex : SV_GroupIndex;
    uint3 groupPos : SV_GroupID;
    uint3 localPos : SV_GroupThreadID;
    uint3 globalPos : SV_DispatchThreadID;
};

[[shader("compute")]]
[numthreads(groupResX, groupResY, 1)]
void filterShadowSss(ComputeInput input) {
    if (input.groupIndex < 5)
        sharedGaussian[input.groupIndex] = half(Gaussian(g_sigmaXY, abs(input.groupIndex - 2)));
    
    uint i_base = uint(input.groupIndex) * 2u;
    if (i_base < sharedBufferSize) {
        int2 uv_base = int2(input.groupPos.xy * WorkgroupSize().xy) - 2;

        for (uint i = 0u; i < 2u; i++) {
            uint i_shared = i_base + i;
            if (i_shared >= sharedBufferSize) break;
            
            int2 uv_i = int2(
                i_shared % sharedBufferResX,
                i_shared / sharedBufferResX);

            int2 uv = uv_base + uv_i;
            float depthL = ap.camera.far;

            half3 sss = half3(0.0);
            half3 shadow = half3(1.0);
            if (all(uv >= 0 && uv < ap.game.screenSize)) {
                shadow = texShadowGB[uv].rgb;
                sss = texSssGB[uv];

                float depth = texDepth[uv].r * 2.0 - 1.0;
                depthL = linearizeDepth(depth, ap.camera.near, ap.camera.far);
            }

            sharedDepth[i_shared] = depthL;
            sharedShadow[i_shared] = shadow;
            sharedSss[i_shared] = sss;
        }
    }

    GroupMemoryBarrierWithGroupSync();

    int2 uv = int2(input.globalPos.xy);
	if (all(uv < ap.game.screenSize)) {
        int2 uv_shared = input.localPos.xy + 2;
        int i_shared = uv_shared.y * sharedBufferResX + uv_shared.x;
    	float depthL = sharedDepth[i_shared];

    	half3 shadow, sss;
        sampleSharedBuffer(uv_shared, depthL, shadow, sss);

    	imgShadowFinal[uv] = shadow;
    	imgSssFinal[uv] = sss;
    }
}
