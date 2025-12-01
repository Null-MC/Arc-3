import aperture;
import buffers.sky;
import lib.common;
import lib.sky.common;
import lib.sky.density;
import lib.sky.scattering;

extern static const int BufferWidth;
extern static const int BufferHeight;
extern static const int BufferDepth;

static const int sunTransmittanceSteps = 40;

[[vk::image_format("rgba16f")]]
RWTexture3D<half3> imgSkyTransmit;


[[shader("compute")]]
[numthreads(8,8,4)]
void bakeSkyTransmission(uint3 globalPos : SV_DispatchThreadID) {
    float2 uv = (globalPos.xy + 0.5) / float2(BufferWidth, BufferHeight);
    if (!all(globalPos < uint3(BufferWidth, BufferHeight, BufferDepth))) return;

    float sunCosTheta = 2.0*uv.x - 1.0;
    sunCosTheta = pow3(sunCosTheta);// * sign(sunCosTheta);

    float sunTheta = safeacos(sunCosTheta);
    float height = lerp(groundRadiusMM, atmosphereRadiusMM, uv.y);
    
    float3 pos = float3(0.0, height, 0.0); 
    float3 sunDir = normalize(float3(0.0, sunCosTheta, -sin(sunTheta)));

    float3 transmittance = 0.0;
    if (rayIntersectSphere(pos, sunDir, groundRadiusMM) <= 0.0) {
        float atmoDist = rayIntersectSphere(pos, sunDir, atmosphereRadiusMM);
        float rainStrength = globalPos.z / float(BufferDepth - 1);

        SkyParameters sky;
        float rainF = smoothstep(0.0, 1.0, rainStrength);
        lerp(skyClear, skyRain, rainF, sky);

        float WorldFogDensity = GetWorldFogDensity(rainStrength);
        sky.mieAbsorptionBase *= WorldFogDensity;
        sky.mieScatteringBase *= WorldFogDensity;
        
        transmittance = 1.0;
        float t = 0.0;

        for (int i = 0; i < sunTransmittanceSteps; i++) {
            float newT = ((i + 0.3)/sunTransmittanceSteps)*atmoDist;
            float dt = newT - t;
            t = newT;
            
            float3 newPos = pos + t*sunDir;
            
            AtmosScatter scatter;
            getScatteringValues(newPos, sky, scatter);
            
            transmittance *= exp(-dt*scatter.extinction);
        }
    }

    // if (globalPos.z == 7)
    //     imgDebug[globalPos.xy] = half4(transmittance, 1.0);

    imgSkyTransmit[globalPos] = half3(saturate(transmittance));
}
