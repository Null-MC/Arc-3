import lib.common;
import lib.sky.common;
import lib.sampling.ERP;

Sampler2D<half3> texSkyIrradiance;

half3 sampleSkyIrradiance(const in float3 localNormal) {
    float2 uv = DirectionToUV(localNormal);

    uv.y = clamp(uv.y, (0.5/skyIrradianceDimensions.y), ((skyIrradianceDimensions.y-0.5)/skyIrradianceDimensions.y));

    return texSkyIrradiance.SampleLevel(uv, 0);
}
