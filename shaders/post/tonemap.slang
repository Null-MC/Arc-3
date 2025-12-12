import aperture;
import lib.common;
import lib.ACES;


extern static const bool Vignette_Enabled;

// static const float Vignette_Bias = 0.65;
static const float Vignette_Size = 1.00;

Sampler2D<half3> texSource;


void ApplyColorGrading(inout float3 aces_cct) {
    float3 s = float3(settings.ToneMap_RedScale, settings.ToneMap_GreenScale, settings.ToneMap_BlueScale);
    float3 o = float3(settings.ToneMap_RedOffset, settings.ToneMap_GreenOffset, settings.ToneMap_BlueOffset);
    float3 p = float3(settings.ToneMap_RedPower, settings.ToneMap_GreenPower, settings.ToneMap_BluePower);
    aces_cct = pow(aces_cct * s + o, p);
}

void ApplyVignette(inout float3 aces_cct, const in float2 texcoord) {
    float dist = length(texcoord * 2.0 - 1.0) * settings.Vignette_Scale;
    aces_cct *= saturate(Vignette_Size - pow3(dist));
}

float3 ApplyRRT(const in float3 aces_cg) {
    // --- Global desaturation --- //
    // half3 x = lerp(dot(aces_cg, AP1_RGB2Y).xxx, aces_cg, RRT_SAT_FACTOR.xxx);
    float3 x = lerp(dot(aces_cg, AP1_RGB2Y), aces_cg, settings.ToneMap_Saturation);

    // Luminance fitting of *RRT.a1.0.3 + ODT.Academy.RGBmonitor_100nits_dim.a1.0.3*.
    // https://github.com/colour-science/colour-unity/blob/master/Assets/Colour/Notebooks/CIECAM02_Unity.ipynb
    // RMSE: 0.0012846272106
    const float a = 278.5085;
    const float b =  10.7772;
    const float c = 293.6045;
    const float d =  88.7122;
    const float e =  80.6889;
    float3 rgb_post = (x * (a * x + b)) / (x * (c * x + d) + e);

    return rgb_post;
}

float3 ApplyODT(const in float3 rgb_post) {
    // Apply gamma adjustment to compensate for dim surround
    half3 linear_CV = ACES_DarkToDimSurround(rgb_post);

    // Apply desaturation to compensate for luminance difference
    linear_CV = lerp(dot(linear_CV, AP1_RGB2Y), linear_CV, ODT_SAT_FACTOR);

    float3 XYZ = mul(AP1_2_XYZ_MAT, linear_CV);
    XYZ = mul(D60_2_D65_CAT, XYZ);

    float3 final = mul(XYZ_2_REC709_MAT, XYZ);
    return saturate(final);
}


[[shader("fragment")]]
half4 applyTonemap(float2 pos : SV_Position) : SV_Target0 {
    float3 aces_cg = texSource[int2(pos)];
    float2 texcoord = pos / ap.game.screenSize;

    float3 aces_cct = ACEScct_from_Linear(aces_cg);

    ApplyColorGrading(aces_cct);

    if (Vignette_Enabled)
        ApplyVignette(aces_cct, texcoord);

    aces_cg = Linear_from_ACEScct(aces_cct);
    aces_cg = max(aces_cg, 0.0);

    float3 rgb_post = ApplyRRT(aces_cg);
    float3 final = ApplyODT(rgb_post);

    return half4(half3(final), 1);
}
