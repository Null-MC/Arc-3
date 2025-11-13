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
groupshared half3 sharedGI[sharedBufferSize];
groupshared float sharedDepth[sharedBufferSize];

[[vk::image_format("rgba16f")]]
RWTexture2D<half4> imgGI_final;

Sampler2D<float> texDepth;
Sampler2D<half3> texGI;


void sampleSharedBuffer(const in uint2 uv_base, const in float depthL, out float3 gi_final) {
    float total = 0.0;
    float3 accum_gi = 0.0;
    
    for (int iy = 0; iy < 5; iy++) {
        float fy = sharedGaussian[iy];

        for (int ix = 0; ix < 5; ix++) {
            float fx = sharedGaussian[ix];
            
            int2 uv_shared = uv_base + (int2(ix, iy) - 2);
            int i_shared = uv_shared.y * sharedBufferResX + uv_shared.x;

            half3 sample_gi = sharedGI[i_shared];
            float sampleDepthL = sharedDepth[i_shared];
            
            float depthDiff = abs(sampleDepthL - depthL);
            float fv = Gaussian(g_sigmaV, depthDiff);
            
            float weight = fx*fy*fv;
            accum_gi += weight * sample_gi;
            total += weight;
        }
    }
    
    //if (total <= EPSILON) return float4(float3(1.0), 0.0);
    gi_final = accum_gi / total;
}


struct ComputeInput {
    uint groupIndex : SV_GroupIndex;
    uint3 groupPos : SV_GroupID;
    uint3 localPos : SV_GroupThreadID;
    uint3 globalPos : SV_DispatchThreadID;
};

[[shader("compute")]]
[numthreads(groupResX, groupResY, 1)]
void filterGI(ComputeInput input) {
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

            half3 gi = half3(0.0);
            if (all(uv >= 0 && uv < ap.game.screenSize)) {
                gi = texGI[uv].rgb;

                float depth = texDepth[uv].r * 2.0 - 1.0;
                depthL = linearizeDepth(depth, ap.camera.near, ap.camera.far);
            }

            sharedDepth[i_shared] = depthL;
            sharedGI[i_shared] = gi;
        }
    }

    GroupMemoryBarrierWithGroupSync();

    int2 uv = int2(input.globalPos.xy);
	if (all(uv < ap.game.screenSize)) {
        int2 uv_shared = input.localPos.xy + 2;
        int i_shared = uv_shared.y * sharedBufferResX + uv_shared.x;
    	float depthL = sharedDepth[i_shared];

    	float3 gi;
        sampleSharedBuffer(uv_shared, depthL, gi);

        float4 gi_prev = imgGI_final[uv];
        float counter = clamp(gi_prev.a, 0, 20);
        gi = lerp(gi_prev.rgb, gi, rcp(counter + 1));
    	imgGI_final[uv] = half4(gi, counter + 1);

        // DEBUG
        imgDebug[uv] = half4(gi * 0.02, (half)1.0);
    }
}
