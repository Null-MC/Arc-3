import aperture;

Sampler2D<half4> texSource;
Sampler2D<half4> texReflect;


[[shader("fragment")]]
half4 overlayReflections(float2 pos : SV_Position) : SV_Target0 {
    uint2 uv = uint2(pos);
    float2 texcoord = pos / ap.game.screenSize;

    half4 color = texSource[uv];
    half4 reflect = texReflect.Sample(texcoord);
    return half4(color + reflect);
}
