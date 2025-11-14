public module scattering;

import lib.common;
import lib.sky.common;


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
