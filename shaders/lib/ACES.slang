public module ACES;


static const half CINEMA_WHITE = 48;
static const half CINEMA_BLACK = (half)(CINEMA_WHITE / 2400.0);
static const half DIM_SURROUND_GAMMA = (half)0.9811;

static const half RRT_SAT_FACTOR = (half)0.96;
static const half ODT_SAT_FACTOR = (half)0.93;

static const half3 AP1_RGB2Y = half3(0.272229, 0.674082, 0.0536895);

static const float3x3 D60_2_D65_CAT = {
     0.98722400, -0.00611327, 0.0159533,
    -0.00759836,  1.00186000, 0.0053302,
     0.00307257, -0.00509595, 1.0816800
};

// static const float3x3 AP0_2_AP1_MAT = {
//      1.4514393161, -0.2365107469, -0.2149285693,
//     -0.0765537734,  1.1762296998, -0.0996759264,
//      0.0083161484, -0.0060324498,  0.9977163014
// };

// static const float3x3 AP1_2_sRGB = {
//     1.70505, -0.62179, -0.08326,
//     -0.13026, 1.14080, -0.01055,
//     -0.02400, -0.12897, 1.15297,
// };

// static const float3x3 AP1_2_AP0_MAT = {
//      0.6954522414, 0.1406786965, 0.1638690622,
//      0.0447945634, 0.8596711185, 0.0955343182,
//     -0.0055258826, 0.0040252103, 1.0015006723
// };

static const float3x3 sRGB_2_AP1 = {
    0.61319, 0.33951, 0.04737,
    0.07021, 0.91634, 0.01345,
    0.02062, 0.10957, 0.86961
};

static const float3x3 AP1_2_XYZ_MAT = {
     0.6624541811, 0.1340042065, 0.1561876870,
     0.2722287168, 0.6740817658, 0.0536895174,
    -0.0055746495, 0.0040607335, 1.0103391003
};

static const float3x3 XYZ_2_AP1_MAT = {
     1.6410233797, -0.3248032942, -0.2364246952,
    -0.6636628587,  1.6153315917,  0.0167563477,
     0.0117218943, -0.0082844420,  0.9883948585
};

static const float3x3 XYZ_2_REC709_MAT = {
     3.2409699419, -1.5373831776, -0.4986107603,
    -0.9692436363,  1.8759675015,  0.0415550574,
     0.0556300797, -0.2039769589,  1.0569715142
};


half3 Y_2_linCV(half3 Y, half Ymax, half Ymin) {
    return (Y - Ymin) / (Ymax - Ymin);
}

half3 XYZ_2_xyY(half3 XYZ) {
    half divisor = max(dot(XYZ, (1.0).xxx), 1e-4);
    return half3(XYZ.xy / divisor, XYZ.y);
}

half3 xyY_2_XYZ(half3 xyY) {
    half m = xyY.z / max(xyY.y, 1e-4);
    half3 XYZ = half3(xyY.xz, (1.0 - xyY.x - xyY.y));
    XYZ.xz *= m;
    return XYZ;
}

float3 ACES_linear_to_cg(const in float3 color) {
    return mul(sRGB_2_AP1, color);
}

half3 ACES_linear_to_cg(const in half3 color) {
    return mul(sRGB_2_AP1, color);
}

float ACEScct_from_Linear(float lin) {
    if (lin > 0.0078125)
        return log2(lin) / 17.52 + (9.72/17.52);
    
	return lin * 10.5402377416545 + 0.0729055341958355;
}

float3 ACEScct_from_Linear(float3 lin) {
    return float3(
        ACEScct_from_Linear(lin.r),
        ACEScct_from_Linear(lin.g),
        ACEScct_from_Linear(lin.b));
}

float Linear_from_ACEScct(float cct) {
    if (cct > 0.155251141552511)
        return exp2(cct * 17.52 - 9.72);
    
	return cct / 10.5402377416545 - (0.0729055341958355/10.5402377416545);
}

float3 Linear_from_ACEScct(float3 cct) {
    return float3(
        Linear_from_ACEScct(cct.r),
        Linear_from_ACEScct(cct.g),
        Linear_from_ACEScct(cct.b));
}

half3 ACES_DarkToDimSurround(half3 linearCV) {
    half3 XYZ = mul(AP1_2_XYZ_MAT, linearCV);

    half3 xyY = XYZ_2_xyY(XYZ);
    xyY.z = clamp(xyY.z, 0.0, half.maxValue);
    xyY.z = pow(xyY.z, DIM_SURROUND_GAMMA);
    XYZ = xyY_2_XYZ(xyY);

    return mul(XYZ_2_AP1_MAT, XYZ);
}

// static const half3x3 M = {
//      0.5, -1.0, 0.5,
//     -1.0,  1.0, 0.0,
//      0.5,  0.5, 0.0
// };

// half segmented_spline_c5_fwd(half x)
// {
//     const half coefsLow[6] = { -4.0000000000, -4.0000000000, -3.1573765773, -0.4852499958, 1.8477324706, 1.8477324706 }; // coefs for B-spline between minPoint and midPoint (units of log luminance)
//     const half coefsHigh[6] = { -0.7185482425, 2.0810307172, 3.6681241237, 4.0000000000, 4.0000000000, 4.0000000000 }; // coefs for B-spline between midPoint and maxPoint (units of log luminance)
//     const half2 minPoint = half2(0.18 * exp2(-15.0), 0.0001); // {luminance, luminance} linear extension below this
//     const half2 midPoint = half2(0.18, 0.48); // {luminance, luminance}
//     const half2 maxPoint = half2(0.18 * exp2(18.0), 10000.0); // {luminance, luminance} linear extension above this
//     const half slopeLow = 0.0; // log-log slope of low linear extension
//     const half slopeHigh = 0.0; // log-log slope of high linear extension

//     const int N_KNOTS_LOW = 4;
//     const int N_KNOTS_HIGH = 4;

//     // Check for negatives or zero before taking the log. If negative or zero,
//     // set to ACESMIN.1
//     float xCheck = x;
//     if (xCheck <= 0.0) xCheck = 0.00006103515; // = pow(2.0, -14.0);

//     half logx = log10(xCheck);
//     half logy;

//     if (logx <= log10(minPoint.x))
//     {
//         logy = logx * slopeLow + (log10(minPoint.y) - slopeLow * log10(minPoint.x));
//     }
//     else if ((logx > log10(minPoint.x)) && (logx < log10(midPoint.x)))
//     {
//         half knot_coord = (N_KNOTS_LOW - 1) * (logx - log10(minPoint.x)) / (log10(midPoint.x) - log10(minPoint.x));
//         int j = knot_coord;
//         half t = knot_coord - j;

//         half3 cf = half3(coefsLow[j], coefsLow[j + 1], coefsLow[j + 2]);
//         half3 monomials = half3(t * t, t, 1.0);
//         logy = dot(monomials, mul(M, cf));
//     }
//     else if ((logx >= log10(midPoint.x)) && (logx < log10(maxPoint.x)))
//     {
//         half knot_coord = (N_KNOTS_HIGH - 1) * (logx - log10(midPoint.x)) / (log10(maxPoint.x) - log10(midPoint.x));
//         int j = knot_coord;
//         half t = knot_coord - j;

//         half3 cf = half3(coefsHigh[j], coefsHigh[j + 1], coefsHigh[j + 2]);
//         half3 monomials = half3(t * t, t, 1.0);
//         logy = dot(monomials, mul(M, cf));
//     }
//     else
//     { //if (logIn >= log10(maxPoint.x)) {
//         logy = logx * slopeHigh + (log10(maxPoint.y) - slopeHigh * log10(maxPoint.x));
//     }

//     return pow(10.0, logy);
// }

// half segmented_spline_c9_fwd(half x) {
//     const half coefsLow[10] = { -1.6989700043, -1.6989700043, -1.4779000000, -1.2291000000, -0.8648000000, -0.4480000000, 0.0051800000, 0.4511080334, 0.9113744414, 0.9113744414 }; // coefs for B-spline between minPoint and midPoint (units of log luminance)
//     const half coefsHigh[10] = { 0.5154386965, 0.8470437783, 1.1358000000, 1.3802000000, 1.5197000000, 1.5985000000, 1.6467000000, 1.6746091357, 1.6878733390, 1.6878733390 }; // coefs for B-spline between midPoint and maxPoint (units of log luminance)
//     const half2 minPoint = half2(segmented_spline_c5_fwd(0.18 * exp2(-6.5)), 0.02); // {luminance, luminance} linear extension below this
//     const half2 midPoint = half2(segmented_spline_c5_fwd(0.18), 4.8); // {luminance, luminance}
//     const half2 maxPoint = half2(segmented_spline_c5_fwd(0.18 * exp2(6.5)), 48.0); // {luminance, luminance} linear extension above this
//     const half slopeLow = 0.0; // log-log slope of low linear extension
//     const half slopeHigh = 0.04; // log-log slope of high linear extension

//     const int N_KNOTS_LOW = 8;
//     const int N_KNOTS_HIGH = 8;

//     // Check for negatives or zero before taking the log. If negative or zero,
//     // set to OCESMIN.
//     half xCheck = x;
//     if (xCheck <= 0.0) xCheck = 1e-4;

//     half logx = log10(xCheck);
//     half logy;

//     if (logx <= log10(minPoint.x)) {
//         logy = logx * slopeLow + (log10(minPoint.y) - slopeLow * log10(minPoint.x));
//     }
//     else if ((logx > log10(minPoint.x)) && (logx < log10(midPoint.x))) {
//         half knot_coord = (N_KNOTS_LOW - 1) * (logx - log10(minPoint.x)) / (log10(midPoint.x) - log10(minPoint.x));
//         int j = knot_coord;
//         half t = knot_coord - j;

//         half3 cf = half3(coefsLow[j], coefsLow[j + 1], coefsLow[j + 2]);
//         half3 monomials = half3(t * t, t, 1.0);
//         logy = dot(monomials, mul(M, cf));
//     }
//     else if ((logx >= log10(midPoint.x)) && (logx < log10(maxPoint.x)))
//     {
//         half knot_coord = (N_KNOTS_HIGH - 1) * (logx - log10(midPoint.x)) / (log10(maxPoint.x) - log10(midPoint.x));
//         int j = knot_coord;
//         half t = knot_coord - j;

//         half3 cf = half3(coefsHigh[j], coefsHigh[j + 1], coefsHigh[j + 2]);
//         half3 monomials = half3(t * t, t, 1.0);
//         logy = dot(monomials, mul(M, cf));
//     }
//     else
//     { //if (logIn >= log10(maxPoint.x)) {
//         logy = logx * slopeHigh + (log10(maxPoint.y) - slopeHigh * log10(maxPoint.x));
//     }

//     return pow(10.0, logy);
// }

// half3 ODT_RGBmonitor_100nits_dim(half3 oces) {
//     // OCES to RGB rendering space
//     half3 rgbPre = mul(AP0_2_AP1_MAT, oces);

//     // Apply the tonescale independently in rendering-space RGB
//     half3 rgbPost;
//     rgbPost.x = segmented_spline_c9_fwd(rgbPre.x);
//     rgbPost.y = segmented_spline_c9_fwd(rgbPre.y);
//     rgbPost.z = segmented_spline_c9_fwd(rgbPre.z);

//     // Scale luminance to linear code value
//     half3 linearCV = Y_2_linCV(rgbPost, CINEMA_WHITE, CINEMA_BLACK);

//      // Apply gamma adjustment to compensate for dim surround
//     linearCV = ACES_DarkToDimSurround(linearCV);

//     // Apply desaturation to compensate for luminance difference
//     //linearCV = mul(ODT_SAT_MAT, linearCV);
//     linearCV = lerp(dot(linearCV, AP1_RGB2Y).xxx, linearCV, ODT_SAT_FACTOR.xxx);

//     // Convert to display primary encoding
//     // Rendering space RGB to XYZ
//     half3 XYZ = mul(AP1_2_XYZ_MAT, linearCV);

//     // CIE XYZ to display primaries
//     half3 final = mul(XYZ_2_REC709_MAT, XYZ);

//     // Handle out-of-gamut values
//     // Clip values < 0 or > 1 (i.e. projecting outside the display primaries)
//     return saturate(final);
// }
