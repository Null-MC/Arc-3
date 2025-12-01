import aperture;
import lib.common;

extern static const uint BLOOM_INDEX;
extern static const uint MIP_INDEX;

Sampler2D<half3> texSource;
Sampler2D<half3> texBloom;


[[shader("fragment")]]
half3 applyBloomDown(float2 pos : SV_Position) : SV_Target0 {
    uint3 texSrc_size;
    texSource.GetDimensions(MIP_INDEX, texSrc_size.x, texSrc_size.y, texSrc_size.z);
    float2 srcPixelSize = rcp(texSrc_size.xy);

    float2 uv = 2.0 * pos * srcPixelSize;

    half3 a = texSource.SampleLevel(uv, MIP_INDEX, int2(-2, +2));
    half3 b = texSource.SampleLevel(uv, MIP_INDEX, int2( 0, +2));
    half3 c = texSource.SampleLevel(uv, MIP_INDEX, int2(+2, +2));

    half3 d = texSource.SampleLevel(uv, MIP_INDEX, int2(-2, 0));
    half3 e = texSource.SampleLevel(uv, MIP_INDEX, int2( 0, 0));
    half3 f = texSource.SampleLevel(uv, MIP_INDEX, int2(+2, 0));

    half3 g = texSource.SampleLevel(uv, MIP_INDEX, int2(-2, -2));
    half3 h = texSource.SampleLevel(uv, MIP_INDEX, int2( 0, -2));
    half3 i = texSource.SampleLevel(uv, MIP_INDEX, int2(+2, -2));

    half3 j = texSource.SampleLevel(uv, MIP_INDEX, int2(-1, +1));
    half3 k = texSource.SampleLevel(uv, MIP_INDEX, int2(+1, +1));
    half3 l = texSource.SampleLevel(uv, MIP_INDEX, int2(-1, -1));
    half3 m = texSource.SampleLevel(uv, MIP_INDEX, int2(+1, -1));

    float3 color =  e  * 0.12500;
    color += (a+c+g+i) * 0.03125;
    color += (b+d+f+h) * 0.06250;
    color += (j+k+l+m) * 0.12500;

    color = clamp(color, 0.0, 65000.0);
    return half3(color);
}


[[shader("fragment")]]
half3 applyBloomUp(float2 pos : SV_Position) : SV_Target0 {
    uint3 texSrc_size;
    texBloom.GetDimensions(MIP_INDEX, texSrc_size.x, texSrc_size.y, texSrc_size.z);
    float2 srcPixelSize = rcp(texSrc_size.xy);

    float2 uv = 0.5 * pos * srcPixelSize;

    half3 a = texBloom.SampleLevel(uv, MIP_INDEX, int2(-1, +1));
    half3 b = texBloom.SampleLevel(uv, MIP_INDEX, int2( 0, +1));
    half3 c = texBloom.SampleLevel(uv, MIP_INDEX, int2(+1, +1));

    half3 d = texBloom.SampleLevel(uv, MIP_INDEX, int2(-1,  0));
    half3 e = texBloom.SampleLevel(uv, MIP_INDEX, int2( 0,  0));
    half3 f = texBloom.SampleLevel(uv, MIP_INDEX, int2(+1,  0));

    half3 g = texBloom.SampleLevel(uv, MIP_INDEX, int2(-1, -1));
    half3 h = texBloom.SampleLevel(uv, MIP_INDEX, int2( 0, -1));
    half3 i = texBloom.SampleLevel(uv, MIP_INDEX, int2(+1, -1));

    float3 color =   e * 0.2500;
    color += (b+d+f+h) * 0.1250;
    color += (a+c+g+i) * 0.0625;

    if (BLOOM_INDEX == 0u) {
        color = fma(color, settings.Bloom_Strength, texSource[int2(pos)]);
    }

    color = clamp(color, 0.0, 65000.0);
    return half3(color);
}
