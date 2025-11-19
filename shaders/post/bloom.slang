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

    half3 a = texSource.SampleLevel(fma(srcPixelSize, float2(-2.0, +2.0), uv), MIP_INDEX);
    half3 b = texSource.SampleLevel(fma(srcPixelSize, float2( 0.0, +2.0), uv), MIP_INDEX);
    half3 c = texSource.SampleLevel(fma(srcPixelSize, float2(+2.0, +2.0), uv), MIP_INDEX);

    half3 d = texSource.SampleLevel(fma(srcPixelSize, float2(-2.0, 0.0), uv), MIP_INDEX);
    half3 e = texSource.SampleLevel(fma(srcPixelSize, float2( 0.0, 0.0), uv), MIP_INDEX);
    half3 f = texSource.SampleLevel(fma(srcPixelSize, float2(+2.0, 0.0), uv), MIP_INDEX);

    half3 g = texSource.SampleLevel(fma(srcPixelSize, float2(-2.0, -2.0), uv), MIP_INDEX);
    half3 h = texSource.SampleLevel(fma(srcPixelSize, float2( 0.0, -2.0), uv), MIP_INDEX);
    half3 i = texSource.SampleLevel(fma(srcPixelSize, float2(+2.0, -2.0), uv), MIP_INDEX);

    half3 j = texSource.SampleLevel(fma(srcPixelSize, float2(-1.0, +1.0), uv), MIP_INDEX);
    half3 k = texSource.SampleLevel(fma(srcPixelSize, float2(+1.0, +1.0), uv), MIP_INDEX);
    half3 l = texSource.SampleLevel(fma(srcPixelSize, float2(-1.0, -1.0), uv), MIP_INDEX);
    half3 m = texSource.SampleLevel(fma(srcPixelSize, float2(+1.0, -1.0), uv), MIP_INDEX);

    half3 color =   e  * half3(0.12500);
    color += (a+c+g+i) * half3(0.03125);
    color += (b+d+f+h) * half3(0.06250);
    color += (j+k+l+m) * half3(0.12500);

    color = clamp(color, half3(0.0), half3(65000.0));
    return color;
}


[[shader("fragment")]]
half3 applyBloomUp(float2 pos : SV_Position) : SV_Target0 {
    uint3 texSrc_size;
    texBloom.GetDimensions(MIP_INDEX, texSrc_size.x, texSrc_size.y, texSrc_size.z);
    float2 srcPixelSize = rcp(texSrc_size.xy);

    float2 uv = 0.5 * pos * srcPixelSize;

    half3 a = texBloom.SampleLevel(fma(srcPixelSize, float2(-1.0, +1.0), uv), MIP_INDEX);
    half3 b = texBloom.SampleLevel(fma(srcPixelSize, float2( 0.0, +1.0), uv), MIP_INDEX);
    half3 c = texBloom.SampleLevel(fma(srcPixelSize, float2(+1.0, +1.0), uv), MIP_INDEX);

    half3 d = texBloom.SampleLevel(fma(srcPixelSize, float2(-1.0,  0.0), uv), MIP_INDEX);
    half3 e = texBloom.SampleLevel(fma(srcPixelSize, float2( 0.0,  0.0), uv), MIP_INDEX);
    half3 f = texBloom.SampleLevel(fma(srcPixelSize, float2(+1.0,  0.0), uv), MIP_INDEX);

    half3 g = texBloom.SampleLevel(fma(srcPixelSize, float2(-1.0, -1.0), uv), MIP_INDEX);
    half3 h = texBloom.SampleLevel(fma(srcPixelSize, float2( 0.0, -1.0), uv), MIP_INDEX);
    half3 i = texBloom.SampleLevel(fma(srcPixelSize, float2(+1.0, -1.0), uv), MIP_INDEX);

    half3 color =    e * half3(0.2500);
    color += (b+d+f+h) * half3(0.1250);
    color += (a+c+g+i) * half3(0.0625);

    if (BLOOM_INDEX == 0u) {
        color = fma(color, half3(settings.Bloom_Strength), texSource[int2(pos)]);
    }

    color = clamp(color, half3(0.0), half3(65000.0));
    return color;
}
