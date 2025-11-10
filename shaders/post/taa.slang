import aperture;
import lib.common;
import lib.sampling.catmull_rom;

extern static const float TAA_RejectionStrength = 0.6;
extern static const int EFFECT_TAA_MAX_ACCUM = 16;
extern static const bool SharpenHistory = true;
static const uint groupResX = 16;
static const uint groupResY = 16;

[[vk::image_format("rgba16f")]]
RWTexture2D<half4> imgFinal;

[[vk::image_format("rgba16f")]]
RWTexture2D<half4> imgFinalPrev;

Sampler2D<half3> texSource;
Sampler2D<half4> texFinalPrev;
Sampler2D<half2> texVelocity;
Sampler2D<float> texDepth;

static const uint sharedBufferResX = groupResX+2;
static const uint sharedBufferResY = groupResY+2;
static const uint sharedBufferSize = sharedBufferResX*sharedBufferResY;
groupshared half3 sharedBuffer[sharedBufferSize];


static const float3x3 RGB_TO_YUV = float3x3(
     0.29900,  0.58700,  0.11400,
    -0.14713, -0.28886,  0.43600,
     0.61500, -0.51499, -0.10001);

static const float3x3 YUV_TO_RGB = float3x3(
    1.00000,  0.00000,  1.13983,
    1.00000, -0.39465, -0.58060,
    1.00000,  2.03211,  0.00000);

float2 getReprojectedClipPos(const in float2 texcoord, const in float depthNow, const in float2 velocity) {
    float3 clipPos = float3(texcoord, depthNow) * 2.0 - 1.0;
    float3 viewPos = project(ap.camera.projectionInv, clipPos);
    float3 localPos = mul3(ap.camera.viewInv, viewPos.xyz);

    float3 localPosPrev = localPos + (ap.camera.position - ap.temporal.position);

    float3 viewPosPrev = mul3(ap.temporal.view, localPosPrev);
    float3 clipPosPrev = project(ap.temporal.projection, viewPosPrev);
    return clipPosPrev.xy * 0.5 + 0.5 - velocity;
}

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
void applyTaa(ComputeInput input) {
    uint i_base = input.groupIndex * 2u;

    if (i_base < sharedBufferSize) {
        uint2 uv_base = input.groupPos.xy * int2(groupResX, groupResY) - 1u;

        [ForceUnroll]
        for (uint i = 0u; i < 2u; i++) {
            uint i_shared = i_base + i;

            if (i_shared < sharedBufferSize) {
                int2 uv_i = getSharedUV(i_shared);
                sharedBuffer[i_shared] = texSource[uv_base + uv_i];
            }
        }
    }

    GroupMemoryBarrierWithGroupSync();

    if (all(input.globalPos.xy < ap.game.screenSize)) {
        float depth = texDepth[input.globalPos.xy].r;
        float2 velocity = float2(0.0);//texVelocity[input.globalPos.xy];

        float2 texcoord = (input.globalPos.xy + 0.5) / float2(ap.game.screenSize);
        float2 uv_prev = getReprojectedClipPos(texcoord, depth, velocity);

        half4 lastColor;
        if (SharpenHistory) {
            lastColor = sample_CatmullRom_RGBA(texFinalPrev, uv_prev, ap.game.screenSize);
        }
        else {
            lastColor = texFinalPrev.SampleLevel(uv_prev, 0);
        }

        float mixRate = clamp(lastColor.a, 0.0, EFFECT_TAA_MAX_ACCUM);

        if (any(saturate(uv_prev) != uv_prev)) mixRate = 0.0;
        
        int2 uv = input.localPos.xy + 1;
        half3 in0 = sharedBuffer[getSharedIndex(uv)];
        half3 in1 = sharedBuffer[getSharedIndex(uv + int2(+1,  0))];
        half3 in2 = sharedBuffer[getSharedIndex(uv + int2(-1,  0))];
        half3 in3 = sharedBuffer[getSharedIndex(uv + int2( 0, +1))];
        half3 in4 = sharedBuffer[getSharedIndex(uv + int2( 0, -1))];
        half3 in5 = sharedBuffer[getSharedIndex(uv + int2(+1, +1))];
        half3 in6 = sharedBuffer[getSharedIndex(uv + int2(-1, +1))];
        half3 in7 = sharedBuffer[getSharedIndex(uv + int2(+1, -1))];
        half3 in8 = sharedBuffer[getSharedIndex(uv + int2(-1, -1))];

        half3 antialiased = lerp(lastColor.rgb * lastColor.rgb, in0 * in0, rcp(1.0 + mixRate));
        antialiased = sqrt(antialiased);

        // antialiased = mul(RGB_TO_YUV, antialiased);        
        // in0 = mul(RGB_TO_YUV, in0);
        // in1 = mul(RGB_TO_YUV, in1);
        // in2 = mul(RGB_TO_YUV, in2);
        // in3 = mul(RGB_TO_YUV, in3);
        // in4 = mul(RGB_TO_YUV, in4);
        // in5 = mul(RGB_TO_YUV, in5);
        // in6 = mul(RGB_TO_YUV, in6);
        // in7 = mul(RGB_TO_YUV, in7);
        // in8 = mul(RGB_TO_YUV, in8);
        
        half3 minColor = minOf(minOf(in0, in1, in2), in3, in4);
        minColor = minOf(minOf(in5, in6, in7), in8, minColor);

        half3 maxColor = maxOf(maxOf(in0, in1, in2), in3, in4);
        maxColor = maxOf(maxOf(in5, in6, in7), in8, maxColor);
        
        half3 preclamping = antialiased;
        antialiased = clamp(antialiased, minColor, maxColor);
            
        float3 diff = antialiased - preclamping;
        float clampAmount = dot(diff, diff);
        mixRate *= rcp(1.0 + TAA_RejectionStrength*clampAmount);
        
        //antialiased = mul(YUV_TO_RGB, antialiased);
        
        imgFinal[input.globalPos.xy] = half4(antialiased, 1.0);
        imgFinalPrev[input.globalPos.xy] = half4(antialiased, mixRate + 1.0);
    }
}
