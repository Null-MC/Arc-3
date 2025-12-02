import aperture;
import lib.common;
import lib.noise.IGN;
import lib.sky.common;
import lib.sky.density;
import lib.sky.scattering;
import lib.water.common;
import lib.voxel.froxel;
import lib.light.floodfill_sky;

extern static const int VL_StepCount = 16;

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

    float viewDist = length(viewPos);
    float3 viewDir = viewPos / viewDist;
    float viewDistFinal = min(viewDist, Froxel_MaxDist);

    float3 viewPosEnd = viewDir * viewDistFinal;
    float3 localPosEnd = mul3(ap.camera.viewInv, viewPosEnd);

    float dither = IGN_TAA(pos);

    float3 scattering = 0.0;
    float3 transmittance = 1.0;

    float stepDist = viewDistFinal / VL_StepCount;
    float3 extinction_base = 0.001 * (scene[0].sky.mieScatteringBase + scene[0].sky.mieAbsorptionBase);

    // TODO: replace this with a better check!
    bool isWater = ap.camera.fluid == 1;

    if (isWater) {
        extinction_base = Water_AbsorbColor;
    }

    for (uint i = 0; i < VL_StepCount; i++) {
        float stepF = (i + dither) / VL_StepCount;

        float3 trace_viewPos = viewPosEnd * stepF;
        float3 ndcPos = project(ap.camera.projection, trace_viewPos);
        float3 trace_bufferPos = Froxel_GetBufferPosition(ndcPos);
        half3 froxel = texFroxel_write.Sample(trace_bufferPos / Froxel_Resolution);

        float3 trace_localPos = localPosEnd * stepF;
        float sample_density = 1.0;
        
        if (!isWater) {
            sample_density = SampleFogDensity(trace_localPos);

            float3 trace_skyBufferPos = FloodFill_Sky_GetBufferPosition(trace_localPos);
            if (FloodFill_Sky_InBounds(trace_skyBufferPos)) {
                float skyLightF = floodfill_sky_sample(trace_skyBufferPos);
                sample_density = lerp(Fog_DensityIndoors, sample_density, skyLightF);
            }
        }

        float3 inScattering = froxel * sample_density;
        float3 extinction = extinction_base * sample_density;
        float3 sampleTransmittance = exp(-max(extinction * stepDist, EPSILON));
        float3 scatteringIntegral = (inScattering - inScattering * sampleTransmittance) / max(extinction, EPSILON);

        scattering += scatteringIntegral * transmittance;
        transmittance *= sampleTransmittance;
    }

    color = half3(color * transmittance + scattering);

    return half4(color, (half)1.0);
}
