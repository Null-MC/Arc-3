import aperture;

Sampler2D<half3> texSource;
Sampler2D<half3> texReflect_final;


[[shader("fragment")]]
half4 overlayReflections(float2 pos : SV_Position) : SV_Target0 {
    uint2 uv = uint2(pos);
    // float2 texcoord = pos / ap.game.screenSize;

    half3 color = texSource[uv];
    half3 reflect = texReflect_final[uv];
    return half4(color + reflect, (half)0.0);
}
