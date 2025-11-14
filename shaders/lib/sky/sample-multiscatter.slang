public module sample_multiscatter;

import lib.common;
import lib.sky.common;

Sampler2D<float3> texSkyMultiScatter;

float3 sampleSkyMultiScatter(const in float3 pos, const in float3 sunDir) {
    float height = length(pos);
    float3 up = pos / height;

    float2 uv;
    uv.x = dot(sunDir, up) * 0.5 + 0.5;
    uv.y = unmix(groundRadiusMM, atmosphereRadiusMM, height);

    return texSkyMultiScatter.SampleLevel(saturate(uv), 0);// * BufferLumScale;
}
