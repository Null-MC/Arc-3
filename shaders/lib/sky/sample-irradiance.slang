public module sample_irradiance;

import lib.common;
import lib.sky.common;
import lib.sampling.ERP;

Sampler2D<half3> texSkyIrradiance;

half3 sampleSkyIrradiance(const in float3 localNormal) {
    float2 uv = DirectionToUV(localNormal);

    // TODO: probably going to regret removing this too, but... later problems
    // uv.y = clamp(uv.y, (0.5/skyIrradianceDimensions.y), ((skyIrradianceDimensions.y-0.5)/skyIrradianceDimensions.y));

    return texSkyIrradiance.SampleLevel(uv, 0);
}
