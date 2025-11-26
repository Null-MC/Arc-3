public module scattering;

import aperture;
import lib.common;
import lib.sky.common;


float getSkyAltitude(const in float3 skyPos) {
    return (length(skyPos) - groundRadiusMM) * 1000.0;
}

float getMieDensity(const in float altitudeKM) {
    return exp(-altitudeKM / 1.2);// * lerp(1.0, 2.0, ap.world.rainStrength);
}

void getScatteringValues(float3 skyPos, out float3 rayleighScattering, out float mieScattering, out float3 extinction) {
    float altitudeKM = getSkyAltitude(skyPos);
    float mieDensity = getMieDensity(altitudeKM);
    float rayleighDensity = exp(-altitudeKM/8.0);

    rayleighScattering = scene[0].sky.rayleighScatteringBase*rayleighDensity;
    float rayleighAbsorption = scene[0].sky.rayleighAbsorptionBase*rayleighDensity;

    mieScattering = scene[0].sky.mieScatteringBase*mieDensity;
    float mieAbsorption = scene[0].sky.mieAbsorptionBase*mieDensity;

    float3 ozoneAbsorption = scene[0].sky.ozoneAbsorptionBase * max(0.0, 1.0 - abs(altitudeKM-25.0)/15.0);

    extinction = rayleighScattering + rayleighAbsorption + mieScattering + mieAbsorption + ozoneAbsorption;
}

// float3 atmosAbsorb(const in float3 skyPos, const in float3 lightDir) {
//     float dist = rayIntersectSphere(skyPos, lightDir, atmosphereRadiusMM);

//     float mieScattering;
//     float3 rayleighScattering, extinction;
//     getScatteringValues(skyPos, rayleighScattering, mieScattering, extinction);
    
//     return 1.0;//exp(-max(0.03 * dist * extinction, EPSILON));
// }
