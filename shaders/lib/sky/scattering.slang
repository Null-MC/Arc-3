public module scattering;

import lib.common;
import lib.sky.common;

static const float mieScatteringF = 0.420;
static const float mieAbsorptionF = 0.080;


void getScatteringValues(float3 pos, out float3 rayleighScattering, out float mieScattering, out float3 extinction) {
    float altitudeKM = (length(pos)-groundRadiusMM) * 1000.0;

    // Note: Paper gets these switched up.
    float rayleighDensity = exp(-altitudeKM/8.0);
    float mieDensity = exp(-altitudeKM/1.2);

    rayleighScattering = scene[0].sky.rayleighScatteringBase*rayleighDensity;
    float rayleighAbsorption = scene[0].sky.rayleighAbsorptionBase*rayleighDensity;

    mieScattering = scene[0].sky.mieScatteringBase*mieDensity;
    float mieAbsorption = scene[0].sky.mieAbsorptionBase*mieDensity;

    float3 ozoneAbsorption = scene[0].sky.ozoneAbsorptionBase * max(0.0, 1.0 - abs(altitudeKM-25.0)/15.0);

    extinction = rayleighScattering + rayleighAbsorption + mieScattering + mieAbsorption + ozoneAbsorption;
}

float3 atmosAbsorb(const in float3 skyPos, const in float3 lightDir) {
    float dist = rayIntersectSphere(skyPos, lightDir, atmosphereRadiusMM);

    float mieScattering;
    float3 rayleighScattering, extinction;
    getScatteringValues(skyPos, rayleighScattering, mieScattering, extinction);
    
    return exp(-max(0.03 * dist * extinction, EPSILON));
}
