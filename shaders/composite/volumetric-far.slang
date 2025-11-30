import aperture;
import buffers.ObjectData;
import lib.common;
import lib.blocks;
import lib.noise.IGN;
import lib.sky.common;
import lib.sky.density;
import lib.sky.scattering;
import lib.water.common;
import lib.voxel.froxel;

extern static const int VL_StepCount = 32;

Sampler2D<half3> texSource;
Sampler3D<half3> texFroxel_write;
Sampler2D<half4> texAlbedoGB_translucent;
Sampler2D<uint2> texMatLightGB_translucent;
Sampler2D<float> solidDepthTex;
Sampler2D<float> mainDepthTex;


[[shader("fragment")]]
half4 overlayVolumetrics(float2 pos : SV_Position) : SV_Target0 {
    uint2 uv = uint2(pos);
    half3 color_opaque = texSource[uv];
    half4 color_trans = texAlbedoGB_translucent[uv];

    if (color_trans.a > 0.0) {
        float2 texcoord = pos / ap.game.screenSize;
        if (TAA_Enabled) texcoord -= scene[0].taa_jitter;

        float depth_opaque = solidDepthTex[uv];
        float3 ndcPos_opaque = float3(texcoord, depth_opaque) * 2.0 - 1.0;
        float3 viewPos_opaque = project(ap.camera.projectionInv, ndcPos_opaque);
        float viewDist_opaque = length(viewPos_opaque);
        // float viewDistFinal_opaque = min(viewDist_opaque, Froxel_MaxDist);

        float depth_translucent = mainDepthTex[uv];
        float3 ndcPos_translucent = float3(texcoord, depth_translucent) * 2.0 - 1.0;
        float3 viewPos_translucent = project(ap.camera.projectionInv, ndcPos_translucent);
        float viewDist_translucent = length(viewPos_translucent);
        // float viewDistFinal_translucent = min(viewDist_translucent, Froxel_MaxDist);

        float3 viewDir = viewPos_opaque / viewDist_opaque;
        float3 viewPosStart = viewDir * viewDist_translucent;
        float3 viewPosEnd = viewDir * viewDist_opaque;

        float3 localPosStart = mul3(ap.camera.viewInv, viewPosStart);
        float3 localPosEnd = mul3(ap.camera.viewInv, viewPosEnd);

        float dither = IGN_TAA(pos);

        float3 scattering = 0.0;
        float3 transmittance = 1.0;

        float traceDist = viewDist_opaque - viewDist_translucent;
        float stepDist = traceDist / VL_StepCount;

        float3 extinction_base = 0.001 * (scene[0].sky.mieScatteringBase + scene[0].sky.mieAbsorptionBase);

        // TODO: replace this with a better check!
        ObjectData_MatLit mat_lit;
        mat_lit.unpackLightOcclusion(texMatLightGB_translucent[uv].g);

        bool isWater = ap.camera.fluid == 0 && mat_lit.blockMapId == BLOCK_WATER;

        if (isWater) {
            extinction_base = Water_AbsorbColor;
        }

        for (uint i = 0; i < VL_StepCount; i++) {
            float stepF = (i + dither) / VL_StepCount;

            float3 trace_localPos = lerp(localPosStart, localPosEnd, stepF);

            float sample_density = isWater ? 1.0
                : SampleFogDensity(trace_localPos);

            float3 trace_viewPos = lerp(viewPosStart, viewPosEnd, stepF);
            float3 ndcPos = project(ap.camera.projection, trace_viewPos);
            float3 trace_bufferPos = Froxel_GetBufferPosition(ndcPos);

            float3 inScattering = 0.0;
            if (Froxel_InBufferBounds(trace_bufferPos)) {
                half3 froxel = texFroxel_write.Sample(trace_bufferPos / Froxel_Resolution);
                inScattering = froxel * sample_density;
            }

            float3 extinction = extinction_base * sample_density;
            float3 sampleTransmittance = exp(-max(extinction * stepDist, EPSILON));
            float3 scatteringIntegral = (inScattering - inScattering * sampleTransmittance) / max(extinction, EPSILON);

            scattering += scatteringIntegral * transmittance;
            transmittance *= sampleTransmittance;
        }

        color_opaque = color_opaque * transmittance + scattering;
    }

    return half4(color_opaque, (half)1.0);
}
