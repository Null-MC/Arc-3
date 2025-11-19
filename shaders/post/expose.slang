import aperture;
import lib.common;

Sampler2D<float4> texSource;

static const float3x3 RGB_TO_XYZ = float3x3(
    0.4124564, 0.3575761, 0.1804375,
    0.2126729, 0.7151522, 0.0721750,
    0.0193339, 0.1191920, 0.9503041);

static const float3x3 XYZ_TO_RGB = float3x3(
     3.2404542, -1.5371385, -0.4985314,
    -0.9692660,  1.8760108,  0.0415560,
     0.0556434, -0.2040259,  1.0572252);

float3 xyz_to_xyY(float3 xyz) {
	float sum = sumOf(xyz);
    return float3(xyz.xy / max(sum, EPSILON), xyz.y);
}

float3 xyY_to_xyz(float3 xyY) {
    float2 xz = float2(xyY.x, 1.0 - xyY.x - xyY.y);
    return float3(xyY.z * xz.xy / max(xyY.y, EPSILON), xyY.z).xzy;
}

float ev_100(const in float luminance, const in float luminance_avg) {
    return luminance / (settings.Exposure_Range * max(luminance_avg, 1.0e-8));
}


[[shader("fragment")]]
float4 applyExposure(float2 pos : SV_Position) : SV_Target0 {
    float3 color = texSource[int2(pos)].rgb;

    float3 xyY = xyz_to_xyY(mul(RGB_TO_XYZ, color));

    float exposureF = clamp(scene[0].exposure, settings.Exposure_Min, settings.Exposure_Max);
    xyY.z = ev_100(xyY.z, exposureF);// * exp2(-settings.Post_ExposureOffset);

	color = mul(XYZ_TO_RGB, xyY_to_xyz(xyY));

    return float4(color, 1.0);
}
