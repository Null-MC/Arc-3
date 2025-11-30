public module sample_multiscatter;

import aperture;
import lib.common;
import lib.sky.common;

Sampler3D<float3> texSkyMultiScatter;

float3 sampleSkyMultiScatter(const in float3 pos, const in float3 sunDir, const in float rainF) {
    float height = length(pos);
    float3 up = pos / height;

    float3 uv;
    uv.x = dot(sunDir, up) * 0.5 + 0.5;
    uv.y = unmix(groundRadiusMM, atmosphereRadiusMM, height);
    uv.z = (saturate(rainF) * 7.0 + 0.5) / 8.0;

    return texSkyMultiScatter.Sample(saturate(uv));
}

float3 sampleSkyMultiScatter(const in float3 pos, const in float3 sunDir) {
    return sampleSkyMultiScatter(pos, sunDir, ap.world.rainStrength);
}
