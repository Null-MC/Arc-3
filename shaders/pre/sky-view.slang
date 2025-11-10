import lib.common;
import lib.sky.common;
import lib.sky.scattering;
import lib.sky.sample_transmit;
import lib.sky.sample_multiscatter;

static const int numScatteringSteps = 32;


float3 raymarchScattering(float3 pos, float3 rayDir, float3 sunDir, float tMax, int numSteps) {
    float cosTheta = dot(rayDir, sunDir);
    
	float miePhaseValue_sun = getMiePhase(cosTheta);
	float rayleighPhaseValue_sun = getRayleighPhase(-cosTheta);

    float miePhaseValue_moon = getMiePhase(-cosTheta);
    float rayleighPhaseValue_moon = getRayleighPhase(cosTheta);

    float3 lum = 0.0;
    float3 transmittance = 1.0;
    float t = 0.0;// 0.00001*(0.25 * farPlane);

    for (int i = 0; i < numSteps; i++) {
        float newT = ((i + 0.3)/numSteps)*tMax;
        float dt = newT - t;
        t = newT;
        
        float3 newPos = pos + t*rayDir;

        float3 rayleighScattering, extinction;
        float mieScattering;
        getScatteringValues(newPos, rayleighScattering, mieScattering, extinction);
        
        float3 sampleTransmittance = exp(-dt*extinction);

        float3 sunTransmittanceLux = sampleSkyTransmit(newPos, sunDir) * scene[0].SunColor;
        float3 moonTransmittanceLux = sampleSkyTransmit(newPos, -sunDir) * scene[0].MoonColor;

        float3 psiMS = sampleSkyMultiScatter(newPos, sunDir) + Sky_MinLight;
        //vec3 psiMS_moon = getValFromMultiScattLUT(texSkyMultiScatter, newPos, sunDir);

        float3 rayleighInScattering_sun = rayleighPhaseValue_sun * sunTransmittanceLux;
        float3 mieInScattering_sun = miePhaseValue_sun * sunTransmittanceLux;

        float3 rayleighInScattering_moon = rayleighPhaseValue_moon * moonTransmittanceLux;
        float3 mieInScattering_moon = miePhaseValue_moon * moonTransmittanceLux;

        float3 inScattering = rayleighScattering * (rayleighInScattering_sun + rayleighInScattering_moon + psiMS)
                          + mieScattering * (mieInScattering_sun + mieInScattering_moon + psiMS);

        // Integrated scattering within path segment.
        float3 scatteringIntegral = (inScattering - inScattering * sampleTransmittance) / extinction;

        lum += scatteringIntegral * transmittance;
        
        transmittance *= sampleTransmittance;
    }

    return lum;
}


[[shader("fragment")]]
float3 bakeSkyView(float2 pos : SV_Position) : SV_Target0 {
    float2 uv = pos / skyViewDimensions;

    float azimuthAngle = (uv.x - 0.5) * 2.0*PI;

    // Non-linear mapping of altitude. See Section 5.3 of the paper.
    float adjV;
    if (uv.y < 0.5) {
		float coord = 1.0 - 2.0*uv.y;
		adjV = -coord*coord;
	} else {
		float coord = uv.y*2.0 - 1.0;
		adjV = coord*coord;
	}
    
    float3 skyPos = getSkyPosition(0.0);
    float height = length(skyPos);
    float3 up = skyPos / height;

    float elevation2 = max(height * height - groundRadiusMM * groundRadiusMM, 0.0);
    float horizonAngle = safeacos(sqrt(elevation2) / height) - 0.5*PI;
    float altitudeAngle = adjV*0.5*PI - horizonAngle;
    
    float cosAltitude = cos(altitudeAngle);
    float3 rayDir = float3(cosAltitude*sin(azimuthAngle), sin(altitudeAngle), -cosAltitude*cos(azimuthAngle));
    
    float sunAltitude = (0.5*PI) - acos(dot(scene[0].SunLocalDir, up));
    float3 sunDirEx = float3(0.0, sin(sunAltitude), -cos(sunAltitude));
    
    float atmoDist = rayIntersectSphere(skyPos, rayDir, atmosphereRadiusMM);
    float groundDist = rayIntersectSphere(skyPos, rayDir, groundRadiusMM);
    float tMax = (groundDist < 0.0) ? atmoDist : groundDist;

    return raymarchScattering(skyPos, rayDir, sunDirEx, tMax, numScatteringSteps);
}
