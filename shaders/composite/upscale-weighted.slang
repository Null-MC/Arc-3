import aperture;
import lib.common;
import lib.sampling.depth;
import lib.sampling.gaussian;

extern static const int BufferWidth;
extern static const int BufferHeight;
extern static const int BufferScale;

static const float2 BufferSize = float2(BufferWidth, BufferHeight);
static const int sharedBufferRes = 16 / BufferScale + 2;
static const float g_sigmaXY = 3.0;

groupshared half sharedGaussian[3];
groupshared half3 sharedColor[sharedBufferRes*sharedBufferRes];
groupshared float sharedDepth[sharedBufferRes*sharedBufferRes];

[[vk::image_format("rgba16f")]]
RWTexture2D<half4> imgDest;

Sampler2D<float> texDepth;
Sampler2D<half3> texSource;


float3 sampleSharedBuffer(const in uint2 uv_base, const in float depthL, const in float depthWeight) {
    float total = 0.0;
    float3 sum = 0.0;

    for (int iy = 0; iy < 3; iy++) {
        half fy = sharedGaussian[iy];

        for (int ix = 0; ix < 3; ix++) {
            half fx = sharedGaussian[ix];

            int2 offset = int2(ix, iy) - 1;
            int2 uv_shared = uv_base + offset;
            int i_shared = uv_shared.y * sharedBufferRes + uv_shared.x;

            // float weight = 1.0 + 3*dot(offset, offset);

            float sampleDepthL = sharedDepth[i_shared];
            float depthDiff = abs(sampleDepthL - depthL) + EPSILON;

            // const float depth_scale = 50.0;
            // float weight = exp(-depthDiff * depth_scale) / (1.0 + 3*dot(offset, offset));
            half fz = (half)saturate(1.0 - depthWeight*depthDiff);

            // if (depthDiff < minDiff) {
            //     minDiff = depthDiff;
            //     nearest_i = i_shared;
            // }
            half weight = fx*fy*fz;
            sum += sharedColor[i_shared] * weight;
            total += weight;
        }
    }

    if (total < EPSILON) return sum;
    return sum / total;
}


struct ComputeInput {
    uint groupIndex : SV_GroupIndex;
    uint3 groupPos : SV_GroupID;
    uint3 localPos : SV_GroupThreadID;
    uint3 globalPos : SV_DispatchThreadID;
};

[[shader("compute")]]
[numthreads(16, 16, 1)]
void upscale_weighted(ComputeInput input) {
    if (input.groupIndex < 3)
        sharedGaussian[input.groupIndex] = half(Gaussian(g_sigmaXY, abs(input.groupIndex - 1)));

    if (input.groupIndex < pow2(sharedBufferRes)) {
        int2 uv_group = (input.groupPos.xy * WorkgroupSize().xy) / BufferScale;

        int2 uv_local = int2(
            input.groupIndex % sharedBufferRes,
            input.groupIndex / sharedBufferRes);
        
        int2 uv = uv_group + uv_local - 1;
        float depthL = ap.camera.far;

        half3 color = half3(0.0);
        if (all(uv >= 0 && uv < BufferSize)) {
            color = texSource[uv];

            uint2 uv_full = uv * BufferScale;

            // if (BufferScale > 1) {
            //     uv_full += (ap.timing.frameCounter % 2) * BufferScale;
            // }

            float depth = texDepth[uv_full].r * 2.0 - 1.0;
            depthL = linearizeDepth(depth, ap.camera.near, ap.camera.far);
        }

        sharedDepth[input.groupIndex] = depthL;
        sharedColor[input.groupIndex] = color;
    }

    GroupMemoryBarrierWithGroupSync();

    int2 uv = int2(input.globalPos.xy);

    // if (BufferScale > 1) {
    //     uv += (ap.timing.frameCounter % 2) * BufferScale;
    // }

	if (all(uv < ap.game.screenSize)) {
        float depth = texDepth[uv].r * 2.0 - 1.0;
        float depthL = linearizeDepth(depth, ap.camera.near, ap.camera.far);

        float depthWeight = rcp(depthL);

        int2 uv_shared = input.localPos.xy/BufferScale + 1;

    	float3 color = sampleSharedBuffer(uv_shared, depthL, depthWeight);

    	imgDest[uv] = half4(float4(color, 1.0));
    }
}
