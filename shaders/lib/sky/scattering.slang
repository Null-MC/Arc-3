public module sky_scattering;

import aperture;
import buffers.sky;
import lib.sky.common;


struct AtmosScatter {
    float3 rayleighScattering;
    float mieScattering;
    float3 extinction;
};


float getSkyAltitude(const in float3 skyPos) {
    return (length(skyPos) - groundRadiusMM) * 1000.0;
}

float getMieDensity(const in float altitudeKM) {
    return exp(-altitudeKM / 1.2);
}

void getScatteringValues(const in float3 skyPos, const in SkyParameters sky, out AtmosScatter result) {
    float altitudeKM = getSkyAltitude(skyPos);
    float mieDensity = getMieDensity(altitudeKM);
    float rayleighDensity = exp(-altitudeKM/8.0);

    result.rayleighScattering = sky.rayleighScatteringBase * rayleighDensity;
    float rayleighAbsorption = sky.rayleighAbsorptionBase * rayleighDensity;

    result.mieScattering = sky.mieScatteringBase * mieDensity;
    float mieAbsorption = sky.mieAbsorptionBase * mieDensity;

    float3 ozoneAbsorption = sky.ozoneAbsorptionBase * max(0.0, 1.0 - abs(altitudeKM-25.0)/15.0);

    result.extinction = (result.rayleighScattering + rayleighAbsorption) + (result.mieScattering + mieAbsorption) + ozoneAbsorption;
}

// float3 atmosAbsorb(const in float3 skyPos, const in float3 lightDir) {
//     float dist = rayIntersectSphere(skyPos, lightDir, atmosphereRadiusMM);

//     float mieScattering;
//     float3 rayleighScattering, extinction;
//     getScatteringValues(skyPos, rayleighScattering, mieScattering, extinction);
    
//     return 1.0;//exp(-max(0.03 * dist * extinction, EPSILON));
// }
