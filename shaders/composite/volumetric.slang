import aperture;
import lib.common;
import lib.sampling.IGN;
import lib.sky.common;
import lib.sky.density;
import lib.sky.scattering;
import lib.sky.sample_multiscatter;
import lib.voxel.froxel;

Sampler2D<float> texDepth;
Sampler2D<half3> texSource;
Sampler3D<half3> texFroxel_write;


[[shader("fragment")]]
half4 overlayVolumetrics(float2 pos : SV_Position) : SV_Target0 {
    uint2 uv = uint2(pos);
    float depth = texDepth[uv];
    half3 color = texSource[uv];

    float2 texcoord = pos / ap.game.screenSize;
    if (TAA_Enabled) texcoord -= scene[0].taa_jitter;

    float3 ndcPos = float3(texcoord, depth) * 2.0 - 1.0;
    float3 viewPos = project(ap.camera.projectionInv, ndcPos);
    // float3 localPos = mul3(ap.camera.viewInv, viewPos);

    float viewDist = length(viewPos);
    float3 viewDir = viewPos / viewDist;
    float viewDistFinal = min(viewDist, Froxel_MaxDist);
    float3 viewPosEnd = viewDir * viewDistFinal;
    float3 localPosEnd = mul3(ap.camera.viewInv, viewPosEnd);

    float dither = InterleavedGradientNoiseTime(pos);

    float3 scattering = 0.0;
    float transmittance = 1.0;

    const int StepCount = 32;
    float stepDist = viewDistFinal / StepCount;

    for (uint i = 0; i < StepCount; i++) {
        float stepF = saturate((i + dither) / StepCount);

        float3 trace_localPos = localPosEnd * stepF;
        float sample_density = SampleFogDensity(trace_localPos);

        float3 trace_viewPos = viewPosEnd * stepF;
        float3 ndcPos = project(ap.camera.projection, trace_viewPos);
        float3 trace_bufferPos = Froxel_GetBufferPosition(ndcPos);

        half3 froxel = texFroxel_write.Sample(trace_bufferPos / Froxel_Resolution);

        float3 inScattering = froxel * sample_density;
        float extinction = (mieScatteringF + mieAbsorptionF) * sample_density;

        float sampleTransmittance = 1.0;
        float3 scatteringIntegral = 0.0;
        if (extinction > EPSILON) {
            sampleTransmittance = exp(-extinction * stepDist);
            scatteringIntegral = (inScattering - inScattering * sampleTransmittance) / extinction;
        }

        scattering += scatteringIntegral * transmittance;
        transmittance *= sampleTransmittance;
    }

    color = color * transmittance + scattering;

    return half4(color, (half)1.0);
}
