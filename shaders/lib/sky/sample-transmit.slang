import lib.common;
import lib.sky.common;

Sampler2D<half3> texSkyTransmit;

half3 sampleSkyTransmit(const in float3 pos, const in float3 sunDir) {
    float height = length(pos);
    float3 up = pos / height;

    float2 uv;
    uv.x = dot(sunDir, up);
    uv.x = pow(abs(uv.x), (1.0/3.0)) * sign(uv.x);
    uv.x = uv.x * 0.5 + 0.5;
    uv.y = unmix(groundRadiusMM, atmosphereRadiusMM, height);

    return texSkyTransmit.SampleLevel(saturate(uv), 0);
}
