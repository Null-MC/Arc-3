import aperture;
import lib.common;
import lib.octohedral;

extern static const int DEBUG_MATERIAL;
extern static const bool DEBUG_HISTOGRAM;

static const int DEBUG_GB_ALBEDO = 1;
static const int DEBUG_GB_NORMAL_GEO = 2;
static const int DEBUG_GB_NORMAL_TEX = 3;
static const int DEBUG_GB_LMCOORD = 4;
static const int DEBUG_GB_OCCLUSION = 5;

Sampler2D<float4> texAlbedoGB;
Sampler2D<uint2> texNormalGB;
Sampler2D<uint2> texMatLightGB;
Sampler1D<uint> texHistogram;

[[shader("fragment")]]
float4 renderDebugOverlay(float2 pos : SV_Position) : SV_Target0 {
    float4 color = float4(0.0);
    uint2 uv = uint2(pos);

    if (DEBUG_MATERIAL > 0) {
        color.a = 1.0;

        switch (DEBUG_MATERIAL) {
            case DEBUG_GB_ALBEDO:
                color.rgb = texAlbedoGB[uv].rgb;
                break;
            case DEBUG_GB_NORMAL_GEO:
                color.rgb = OctDecode(unpackUnorm4x8ToHalf(texNormalGB[uv].r).xy) * 0.5 + 0.5;
                break;
            case DEBUG_GB_NORMAL_TEX:
                color.rgb = OctDecode(unpackUnorm4x8ToHalf(texNormalGB[uv].r).zw) * 0.5 + 0.5;
                break;
            case DEBUG_GB_LMCOORD:
                color.rgb = unpackUnorm4x8ToFloat(texMatLightGB[uv].g).rrg;
                break;
            case DEBUG_GB_OCCLUSION:
                color.rgb = unpackUnorm4x8ToFloat(texMatLightGB[uv].g).bbb;
                break;
        }
    }

    // if (DEBUG_NORMALS) {
    //     uint2 uv = uint2(pos);
    //     float4 light = unpackUnorm4x8ToFloat(texMatLightGB[uv].g);
    //     color = float4(light.rg, 0.0, 1.0);
    // }

    if (DEBUG_HISTOGRAM) {
        float2 previewCoord = (pos - 8.0) / float2(256.0, 32.0);
        if (all(saturate(previewCoord) == previewCoord)) {
            uint sampleVal = texHistogram.SampleLevel(previewCoord.x, 0);
            color.gb = float2(step(previewCoord.y*previewCoord.y, sampleVal / float(ap.game.screenSize.x*ap.game.screenSize.y)));
            color.ra = float2(0.0, 1.0);

            float meter = saturate(unmix(settings.Post_ExposureMin, settings.Post_ExposureMax, log2(scene[0].exposure)));
            if (abs(previewCoord.x - meter) < (4.0/ap.game.screenSize.x))
                color.r = 1.0 - color.r;

            // float shit2 = saturate(unmix(settings.Post_ExposureMin, settings.Post_ExposureMax, log2(Scene_AvgExposure) + Post_ExposureOffset));
            // if (abs(previewCoord.x - shit2) < 0.008)
            //     color.b = 1.0 - color.b;
        }
    }

    color.rgb = RgbToLinear(color.rgb);

    return color;
}
