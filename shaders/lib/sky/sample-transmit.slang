public module sample_transmit;

import aperture;
import lib.common;
import lib.sky.common;

Sampler3D<half3> texSkyTransmit;

half3 sampleSkyTransmit(const in float3 pos, const in float3 sunDir, const in float rainF) {
    float height = length(pos);
    float3 up = pos / height;

    float3 uv;
    uv.x = dot(sunDir, up);
    uv.x = pow(abs(uv.x), (1.0/3.0)) * sign(uv.x);
    uv.x = uv.x * 0.5 + 0.5;

    uv.y = unmix(groundRadiusMM, atmosphereRadiusMM, height);

    uv.z = (saturate(rainF) * 7.0 + 0.5) / 8.0;

    return texSkyTransmit.Sample(saturate(uv));
}

half3 sampleSkyTransmit(const in float3 pos, const in float3 sunDir) {
    return sampleSkyTransmit(pos, sunDir, ap.world.rainStrength);
}
