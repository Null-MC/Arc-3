import aperture;
import lib.common;

static const uint groupResX = 16;
static const uint groupResY = 16;

[[vk::image_format("rgba16f")]]
RWTexture2D<half3> imgFinal;

Sampler2D<half3> texSource;

static const uint sharedBufferResX = groupResX+2;
static const uint sharedBufferResY = groupResY+2;
static const uint sharedBufferSize = sharedBufferResX*sharedBufferResY;
groupshared half3 sharedBuffer[sharedBufferSize];

uint2 getSharedUV(const in uint z) {
    return uint2(
        z % sharedBufferResX,
        uint(z / float(sharedBufferResX))
    );
}

int getSharedIndex(const in int2 uv) {
    return uv.y * sharedBufferResX + uv.x;
}

struct ComputeInput {
    uint groupIndex : SV_GroupIndex;
    uint3 groupPos : SV_GroupID;
    uint3 localPos : SV_GroupThreadID;
    uint3 globalPos : SV_DispatchThreadID;
};

[[shader("compute")]]
[numthreads(groupResX, groupResY, 1)]
void sharpen(ComputeInput input) {
    uint i_base = input.groupIndex * 2u;

    if (i_base < sharedBufferSize) {
        // preload shared memory
        uint2 uv_base = input.groupPos.xy * uint2(groupResX, groupResY) - 1u;

        [ForceUnroll]
        for (uint i = 0u; i < 2u; i++) {
            uint i_shared = i_base + i;

            if (i_shared < sharedBufferSize) {
                int2 uv_i = getSharedUV(i_shared);
                half3 color = texSource[uv_base + uv_i].rgb;
                sharedBuffer[i_shared] = color;
            }
        }
    }

    GroupMemoryBarrierWithGroupSync();

    if (all(input.globalPos.xy < ap.game.screenSize)) {
        // Simplified version of "slow" CAS without upscaling or better diagonals
        // https://github.com/GPUOpen-Effects/FidelityFX-CAS/blob/master/ffx-cas/ffx_cas.h#L423

        const float peak = -rcp(lerp(8.0, 5.0, settings.Post_TAA_CasStrength));

        int2 uv = input.localPos.xy + 1;
        half3 b = sharedBuffer[getSharedIndex(uv + int2( 0,-1))];
        half3 d = sharedBuffer[getSharedIndex(uv + int2(-1, 0))];
        half3 e = sharedBuffer[getSharedIndex(uv)];
        half3 f = sharedBuffer[getSharedIndex(uv + int2( 1, 0))];
        half3 h = sharedBuffer[getSharedIndex(uv + int2( 0, 1))];

        half3 area_min = minOf(minOf(d, e, f), b, h);
        half3 area_max = maxOf(maxOf(d, e, f), b, h);

        float3 amp = min(area_min, 1.0 - area_max) * rcp(area_max);
        float3 w = sqrt(saturate(amp)) * peak;

        float3 weight_inv = rcp(1.0 + 4.0*w);
        float3 color = ((b + d + f + h) * w + e) * weight_inv;

        imgFinal[input.globalPos.xy] = half3(saturate(color));
    }
}
