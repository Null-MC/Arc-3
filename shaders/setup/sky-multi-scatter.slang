import aperture;
import buffers.sky;
import lib.common;
import lib.sky.common;
import lib.sky.density;
import lib.sky.scattering;
import lib.sky.sample_transmit;

static const uint3 viewportDimensions = uint3(32, 32, 8);
static const float mulScattSteps = 20.0;
static const int sqrtSamples = 8;

[[vk::image_format("rgba16f")]]
RWTexture3D<half3> imgSkyMultiScatter;

Sampler2D<float3> texSkyTransmit;


float3 getSphericalDir(float theta, float phi) {
    float cosPhi = cos(phi);
    float sinPhi = sin(phi);
    float cosTheta = cos(theta);
    float sinTheta = sin(theta);
    return float3(sinPhi*sinTheta, cosPhi, sinPhi*cosTheta);
}

void getMulScattValues(float3 pos, float3 sunDir, float rainStrength, out float3 lumTotal, out float3 fms) {
    SkyParameters sky;
    float rainF = smoothstep(0.0, 1.0, rainStrength);
    lerp(skyClear, skyRain, rainF, sky);

    float WorldFogDensity = GetWorldFogDensity(rainStrength);
    sky.mieAbsorptionBase *= WorldFogDensity;
    sky.mieScatteringBase *= WorldFogDensity;

    lumTotal = 0.0;
    fms = 0.0;

    for (int i = 0; i < sqrtSamples; i++) {
        for (int j = 0; j < sqrtSamples; j++) {
            // This integral is symmetric about theta = 0 (or theta = PI), so we
            // only need to integrate from zero to PI, not zero to 2*PI.
            float theta = PI * (i + 0.5) / sqrtSamples;
            float phi = safeacos(1.0 - 2.0*(j + 0.5) / sqrtSamples);
            float3 rayDir = getSphericalDir(theta, phi);

            float atmoDist = rayIntersectSphere(pos, rayDir, atmosphereRadiusMM);
            float groundDist = rayIntersectSphere(pos, rayDir, groundRadiusMM);

            float tMax = atmoDist;
            if (groundDist > 0.0) {
                tMax = groundDist;
            }

            float VoL_sun = dot(rayDir, sunDir);
            float miePhase_sun = getMiePhase(VoL_sun);
            float rayleighPhase_sun = getRayleighPhase(-VoL_sun);

            float VoL_moon = -VoL_sun;
            float miePhase_moon = getMiePhase(VoL_moon);
            float rayleighPhase_moon = getRayleighPhase(-VoL_moon);

            float3 lum = 0.0, lumFactor = 0.0, transmittance = 1.0;

            float t = 0.0;
            for (float stepI = 0.0; stepI < mulScattSteps; stepI += 1.0) {
                float newT = ((stepI + 0.3)/mulScattSteps)*tMax;
                float dt = newT - t;
                t = newT;

                float3 newPos = pos + t*rayDir;

                // float mieScattering;
                // float3 rayleighScattering, extinction;
                // getScatteringValues(newPos, rayleighScattering, mieScattering, extinction);

                AtmosScatter scatter;
                getScatteringValues(newPos, sky, scatter);

                float3 sampleTransmittance = exp(-dt*scatter.extinction);

                // Integrate within each segment.
                float3 scatteringNoPhase = scatter.rayleighScattering + scatter.mieScattering;
                float3 scatteringF = (scatteringNoPhase - scatteringNoPhase * sampleTransmittance) / scatter.extinction;
                lumFactor += transmittance*scatteringF;

                // This is slightly different from the paper, but I think the paper has a mistake?
                // In equation (6), I think S(x,w_s) should be S(x-tv,w_s).
                float3 sunTransmittanceLux = sampleSkyTransmit(newPos, sunDir) * scene[0].SunColor;
                float3 moonTransmittanceLux = sampleSkyTransmit(newPos, -sunDir) * scene[0].MoonColor;

                float3 rayleighInScattering_sun = scatter.rayleighScattering * rayleighPhase_sun;
                float mieInScattering_sun = scatter.mieScattering * miePhase_sun;

                float3 rayleighInScattering_moon = scatter.rayleighScattering * rayleighPhase_moon;
                float mieInScattering_moon = scatter.mieScattering * miePhase_moon;

                float3 inScattering = (rayleighInScattering_sun + mieInScattering_sun) * sunTransmittanceLux
                                  + (rayleighInScattering_moon + mieInScattering_moon) * moonTransmittanceLux
                                  + Sky_MinLight;

                // Integrated scattering within path segment.
                float3 scatteringIntegral = (inScattering - inScattering * sampleTransmittance) / scatter.extinction;

                lum += scatteringIntegral * transmittance;
                transmittance *= sampleTransmittance;
            }

            if (groundDist > 0.0) {
                float3 hitPos = pos + groundDist*rayDir;
                if (dot(pos, sunDir) > 0.0) {
                    hitPos = normalize(hitPos) * groundRadiusMM;
                    lum += transmittance * groundAlbedo * sampleSkyTransmit(hitPos, sunDir);
                }
            }

            fms += lumFactor;
            lumTotal += lum;
        }
    }

    const float invSamples = rcp(sqrtSamples*sqrtSamples);
    fms *= invSamples;
    lumTotal *= invSamples;
}


[[shader("compute")]]
[numthreads(8,8,4)]
void bakeSkyMultiScattering(uint3 globalPos : SV_DispatchThreadID) {
    float2 uv = (globalPos.xy + 0.5) / viewportDimensions.xy;
    if (!all(globalPos < viewportDimensions)) return;

    float sunCosTheta = 2.0*uv.x - 1.0;
    float sunTheta = safeacos(sunCosTheta);
    float height = lerp(groundRadiusMM, atmosphereRadiusMM, uv.y);
    
    float3 pos = float3(0.0, height, 0.0); 
    float3 sunDir = normalize(float3(0.0, sunCosTheta, -sin(sunTheta)));
    
    float rainStrength = globalPos.z / float(viewportDimensions.z - 1);

    float3 lum, f_ms;
    getMulScattValues(pos, sunDir, rainStrength, lum, f_ms);

    imgSkyMultiScatter[globalPos] = half3(lum / max(1.0 - f_ms, EPSILON)); 
}
