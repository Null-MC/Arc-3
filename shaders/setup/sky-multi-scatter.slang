import aperture;
import lib.common;
import lib.sky.common;
import lib.sky.scattering;
import lib.sky.sample_transmit;

static const float mulScattSteps = 20.0;
static const int sqrtSamples = 8;

Sampler2D<float3> texSkyTransmit;


float3 getSphericalDir(float theta, float phi) {
    float cosPhi = cos(phi);
    float sinPhi = sin(phi);
    float cosTheta = cos(theta);
    float sinTheta = sin(theta);
    return float3(sinPhi*sinTheta, cosPhi, sinPhi*cosTheta);
}

void getMulScattValues(float3 pos, float3 sunDir, out float3 lumTotal, out float3 fms) {
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

                float3 rayleighScattering, extinction;
                float mieScattering;
                getScatteringValues(newPos, rayleighScattering, mieScattering, extinction);

                float3 sampleTransmittance = exp(-dt*extinction);

                // Integrate within each segment.
                float3 scatteringNoPhase = rayleighScattering + mieScattering;
                float3 scatteringF = (scatteringNoPhase - scatteringNoPhase * sampleTransmittance) / extinction;
                lumFactor += transmittance*scatteringF;

                // This is slightly different from the paper, but I think the paper has a mistake?
                // In equation (6), I think S(x,w_s) should be S(x-tv,w_s).
                float3 sunTransmittanceLux = sampleSkyTransmit(newPos, sunDir) * scene[0].SunColor;
                float3 moonTransmittanceLux = sampleSkyTransmit(newPos, -sunDir) * scene[0].MoonColor;

                float3 rayleighInScattering_sun = rayleighScattering * rayleighPhase_sun;
                float mieInScattering_sun = mieScattering * miePhase_sun;

                float3 rayleighInScattering_moon = rayleighScattering * rayleighPhase_moon;
                float mieInScattering_moon = mieScattering * miePhase_moon;

                float3 inScattering = (rayleighInScattering_sun + mieInScattering_sun) * sunTransmittanceLux
                                  + (rayleighInScattering_moon + mieInScattering_moon) * moonTransmittanceLux
                                  + Sky_MinLight;

                // Integrated scattering within path segment.
                float3 scatteringIntegral = (inScattering - inScattering * sampleTransmittance) / extinction;

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


[[shader("fragment")]]
float3 bakeSkyMultiScattering(float2 pos : SV_Position) : SV_Target0 {
    const uint2 viewportDimensions = 32;
    float2 uv = pos / viewportDimensions;

    float sunCosTheta = 2.0*uv.x - 1.0;
    float sunTheta = safeacos(sunCosTheta);
    float height = lerp(groundRadiusMM, atmosphereRadiusMM, uv.y);
    
    float3 pos = float3(0.0, height, 0.0); 
    float3 sunDir = normalize(float3(0.0, sunCosTheta, -sin(sunTheta)));
    
    float3 lum, f_ms;
    getMulScattValues(pos, sunDir, lum, f_ms);

    return lum / (1.0 - f_ms); 
}
