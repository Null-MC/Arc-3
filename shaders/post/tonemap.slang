import aperture;
import lib.common;
import lib.ACES;

Sampler2D<half3> texSource;


[[shader("fragment")]]
half4 applyTonemap(float2 pos : SV_Position) : SV_Target0 {
    half3 aces_cg = texSource[int2(pos)];

    // float3 aces = mul(AP1_2_AP0_MAT, aces_cg);
    float3 aces_cct = ACEScct_from_Linear(aces_cg);

    // Color Grading
    // TODO: add settings
    float3 s = float3(1.0, 1.0, 1.0);
    float3 o = float3(0.0, 0.0, 0.0);
    float3 p = float3(1.0, 1.0, 1.0);
    aces_cct = pow(aces_cct * s + o, p);

    aces_cg = Linear_from_ACEScct(aces_cct);
    // aces_cg = mul(AP0_2_AP1_MAT, aces);

    aces_cg = max(aces_cg, (half)0.0);

    // --- Global desaturation --- //
    half3 x = lerp(dot(aces_cg, AP1_RGB2Y).xxx, aces_cg, RRT_SAT_FACTOR.xxx);

    // Luminance fitting of *RRT.a1.0.3 + ODT.Academy.RGBmonitor_100nits_dim.a1.0.3*.
    // https://github.com/colour-science/colour-unity/blob/master/Assets/Colour/Notebooks/CIECAM02_Unity.ipynb
    // RMSE: 0.0012846272106
    const float a = 278.5085;
    const float b =  10.7772;
    const float c = 293.6045;
    const float d =  88.7122;
    const float e =  80.6889;
    float3 rgb_post = (x * (a * x + b)) / (x * (c * x + d) + e);

    // Apply gamma adjustment to compensate for dim surround
    half3 linear_CV = ACES_DarkToDimSurround(half3(rgb_post));

    // Apply desaturation to compensate for luminance difference
    linear_CV = lerp(dot(linear_CV, AP1_RGB2Y).xxx, linear_CV, ODT_SAT_FACTOR.xxx);

    half3 XYZ = mul(AP1_2_XYZ_MAT, linear_CV);
    XYZ = mul(D60_2_D65_CAT, XYZ);

    half3 final = mul(XYZ_2_REC709_MAT, XYZ);
    final = saturate(final);

    return half4(final, 1);
}
