import aperture;
import lib.common;
import lib.sampling.IGN;
import lib.voxel.froxel;

Sampler2D<float> texDepth;
Sampler2D<half3> texSource;
Sampler3D<half4> texFroxel_write;


[[shader("fragment")]]
half4 overlayVolumetrics(float2 pos : SV_Position) : SV_Target0 {
    uint2 uv = uint2(pos);
    float depth = texDepth[uv];
    half3 color = texSource[uv];

    float2 texcoord = pos / ap.game.screenSize;
    if (TAA_Enabled) texcoord -= scene[0].taa_jitter;

    float3 ndcPos = float3(texcoord, depth) * 2.0 - 1.0;
    float3 viewPos = project(ap.camera.projectionInv, ndcPos);

    float viewDist = length(viewPos);
    float3 viewDir = viewPos / viewDist;
    float viewDistFinal = min(viewDist, Froxel_MaxDist);
    float3 viewPosEnd = viewDir * viewDistFinal;

    float dither = InterleavedGradientNoiseTime(pos);

    float3 scattering = 0.0;
    float transmit = 1.0;

    const int StepCount = 32;
    float stepDist = viewDistFinal / StepCount;
    float density;
    
    switch (DIMENSION) {
        case DIM_END:
            density = 0.010;
            break;
        case DIM_NETHER:
            density = 0.020;
            break;
        default:
            density = lerp(0.006, 0.030, ap.world.rainStrength);
            break;
    }

    for (uint i = 0; i <= StepCount; i++) {
        float stepF = saturate((i + dither) / StepCount);
        float3 trace_viewPos = lerp(0.0, viewPosEnd, stepF);
        float3 trace_localPos = mul3(ap.camera.viewInv, trace_viewPos);

        float3 ndcPos = project(ap.camera.projection, trace_viewPos);
        float3 trace_bufferPos = Froxel_GetBufferPosition(ndcPos);
        half4 froxel = texFroxel_write.Sample(trace_bufferPos / Froxel_Resolution);

        float3 sample_lit = froxel.rgb;

        scattering += density * stepDist * sample_lit;
    }

    color = color * transmit + scattering;

    return half4(color, (half)1.0);
}
