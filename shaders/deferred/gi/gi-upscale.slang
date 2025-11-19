import aperture;
import lib.common;
import lib.sampling.depth;
import lib.sampling.gaussian;

extern static const int BufferWidth;
extern static const int BufferHeight;
extern static const int BufferScale;

static const float2 BufferSize = float2(BufferWidth, BufferHeight);

// static const uint groupResX = 16;
// static const uint groupResY = 16;
static const int sharedBufferRes = 16 / BufferScale + 2;
// static const int sharedBufferResY = groupResY+4;
// static const int sharedBufferSize = sharedBufferResX*sharedBufferResY;

static const float g_sigmaXY = 3.0;
static const float g_sigmaV = 0.08;

groupshared half sharedGaussian[5];
groupshared half3 sharedGI[sharedBufferRes*sharedBufferRes];
groupshared float sharedDepth[sharedBufferRes*sharedBufferRes];

[[vk::image_format("rgba16f")]]
RWTexture2D<half4> imgGI_final;

Sampler2D<float> texDepth;
Sampler2D<half3> texSource;


float3 sampleSharedBuffer(const in uint2 uv_base, const in float depthL) {
    float total = 0.0;
    float3 accum_gi = 0.0;
    
    int nearest_i;
    float minDiff = float.maxValue;
    for (int iy = 0; iy < 3; iy++) {
        for (int ix = 0; ix < 3; ix++) {
            int2 uv_shared = uv_base + (int2(ix, iy) - 1);
            int i_shared = uv_shared.y * sharedBufferRes + uv_shared.x;

            float sampleDepthL = sharedDepth[i_shared];
            float depthDiff = abs(sampleDepthL - depthL);

            if (depthDiff < minDiff) {
                minDiff = depthDiff;
                nearest_i = i_shared;
            }
        }
    }

    return sharedGI[nearest_i];



    // for (int iy = 0; iy < 3; iy++) {
    //     float fy = sharedGaussian[iy];

    //     for (int ix = 0; ix < 3; ix++) {
    //         float fx = sharedGaussian[ix];
            
    //         int2 uv_shared = uv_base + (int2(ix, iy) - 1);
    //         int i_shared = uv_shared.y * sharedBufferRes + uv_shared.x;

    //         half3 sample_gi = sharedGI[i_shared];
    //         float sampleDepthL = sharedDepth[i_shared];
            
    //         float depthDiff = abs(sampleDepthL - depthL);
    //         float fv = Gaussian(g_sigmaV, depthDiff);
            
    //         float weight = fx*fy*fv;
    //         accum_gi += weight * sample_gi;
    //         total += weight;
    //     }
    // }
    
    // if (total <= EPSILON) return 0.0;
    // return accum_gi / total;
}


struct ComputeInput {
    uint groupIndex : SV_GroupIndex;
    uint3 groupPos : SV_GroupID;
    uint3 localPos : SV_GroupThreadID;
    uint3 globalPos : SV_DispatchThreadID;
};

[[shader("compute")]]
[numthreads(16, 16, 1)]
void upscaleGI(ComputeInput input) {
    if (input.groupIndex < 5)
        sharedGaussian[input.groupIndex] = half(Gaussian(g_sigmaXY, abs(input.groupIndex - 2)));
    
    if (input.groupIndex < pow2(sharedBufferRes)) {
        int2 uv_group = (input.groupPos.xy * WorkgroupSize().xy) / BufferScale;

        int2 uv_local = int2(
            input.groupIndex % sharedBufferRes,
            input.groupIndex / sharedBufferRes);
        
        int2 uv = uv_group + uv_local - 1;
        float depthL = ap.camera.far;

        half3 gi = half3(0.0);
        if (all(uv >= 0 && uv < BufferSize)) {
            gi = texSource[uv];

            uint2 uv_full = uv * BufferScale;
            float depth = texDepth[uv_full].r * 2.0 - 1.0;
            depthL = linearizeDepth(depth, ap.camera.near, ap.camera.far);
        }

        sharedDepth[input.groupIndex] = depthL;
        sharedGI[input.groupIndex] = gi;
    }

    GroupMemoryBarrierWithGroupSync();

    int2 uv = int2(input.globalPos.xy);
	if (all(uv < ap.game.screenSize)) {
        float depth = texDepth[uv].r * 2.0 - 1.0;
        float depthL = linearizeDepth(depth, ap.camera.near, ap.camera.far);

        int2 uv_shared = input.localPos.xy/BufferScale + 1;

    	float3 gi = sampleSharedBuffer(uv_shared, depthL);

    	imgGI_final[uv] = half4(float4(gi, 1.0));

        // TODO: DEBUG
        // imgDebug[uv] = half4(gi * 0.02, (half)1.0);
    }
}
