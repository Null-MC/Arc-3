import aperture;
import buffers.ObjectData;
import lib.common;
import lib.blocks;
import lib.water.common;
import lib.material.pbr;
import lib.material.rough_normal;

extern static const int RefractMode;
extern static const bool Refract_Rough;

Sampler2D<float> mainDepthTex;
Sampler2D<float> solidDepthTex;

Sampler2D<half3> texFinal_opaque;
Sampler2D<half4> texFinal_translucent;

Sampler2D<half3> texTintTranslucent;
Sampler2D<uint2> texNormalGB_translucent;
Sampler2D<uint2> texMatLightGB_translucent;

Sampler2D<half4> texWeather;


void ss_refract(inout float2 uv, const in float3 viewPos, const in float3 refractViewDir) {
    float viewDist = length(viewPos);
    float3 refractViewEnd = viewPos + 0.2 * viewDist * normalize(refractViewDir);
    float3 screenStart = project(ap.camera.projection, viewPos) * 0.5 + 0.5;
    float3 screenEnd = project(ap.camera.projection, refractViewEnd) * 0.5 + 0.5;

    float3 screenStep = screenEnd - screenStart;
    screenStep /= length(screenStep.xy);
    screenStep /= ap.game.screenSize.x;
    screenStep *= 4.0;
    // TODO: aspect correct?

    int i = 1;
    for (; i <= 32; i++) {
        float3 tracePos = i * screenStep + screenStart;
        float depth_opaque = solidDepthTex.Sample(tracePos.xy).r;
        if (depth_opaque < tracePos.z) break;
    }
    
    uv = max(i-1.5, 0.0) * screenStep.xy + screenStart.xy;
}


[[shader("fragment")]]
float4 applyOverlays(float2 pos : SV_Position) : SV_Target0 {
    uint2 uv = uint2(pos);

    half4 weather = texWeather[uv];
    half3 tint = texTintTranslucent[uv];
    half4 translucent = texFinal_translucent[uv];

    float2 texcoord = pos / ap.game.screenSize;
    if (TAA_Enabled) texcoord -= scene[0].taa_jitter;

    float transDepth = mainDepthTex[uv];
    float opaqueDepth = solidDepthTex[uv];

    float3 opaqueClipPos = float3(texcoord, opaqueDepth) * 2.0 - 1.0;
    float3 opaqueViewPos = project(ap.camera.projectionInv, opaqueClipPos);

    float3 transClipPos = float3(texcoord, transDepth) * 2.0 - 1.0;
    float3 transViewPos = project(ap.camera.projectionInv, transClipPos);
    float3 transLocalPos = mul3(ap.camera.viewInv, transViewPos);

    float3 viewDir = normalize(transViewPos);
    float3 localDir = normalize(transLocalPos);

    // uint2 water_uv = uv;
    float2 refract_texcoord = texcoord;
    float transDist = length(transViewPos);
    half3 opaque_color = texFinal_opaque[uv];

    ObjectData_MatLit mat_lit;
    mat_lit.unpack(texMatLightGB_translucent[uv]);

    bool hasOverlay = translucent.a > 0.0;
    bool hasRefract = RefractMode != Refract_None && hasOverlay;

    if (hasRefract) {
        float3 tex_normal = ObjectData_Normals.unpackTex(texNormalGB_translucent[uv].g);

        half roughness = mat_roughness(mat_lit.specular.r);
        half roughL = pow2(roughness);

        float3 refract_normal = Refract_Rough
            ? randomizeNormal(uv, tex_normal, roughL)
            : tex_normal;

        const float IOR_AIR     = 1.0003;
        const float IOR_WATER   = 1.333;
        const float IOR_DEFAULT = 1.5;
        // TODO: store and use actual translucent IOR
        const float ETA_AIR_TO_WATER = (IOR_AIR/IOR_WATER);
        const float ETA_WATER_TO_AIR = 1.02;// (IOR_WATER/IOR_AIR);
        float eta = ap.camera.fluid == 1 ? ETA_WATER_TO_AIR : ETA_AIR_TO_WATER;

        float3 refract_viewNormal = mul(float3x3(ap.camera.view), refract_normal);
        float3 refract_viewDir = refract(viewDir, refract_viewNormal, eta);
        float3 refract_viewPos = transDist * viewDir;

        if (dot(refract_viewDir, refract_viewDir) < EPSILON) {
            refract_texcoord = -1.0;
            opaque_color = half3(0.0);
        }
        else {
            if (RefractMode == Refract_ScreenSpace) {
                ss_refract(refract_texcoord, refract_viewPos, refract_viewDir);
                refract_texcoord = saturate(refract_texcoord) + scene[0].taa_jitter;

                opaqueDepth = solidDepthTex.Sample(refract_texcoord);
                opaque_color = texFinal_opaque.Sample(refract_texcoord);
            }
        }
    }

    bool isWater = false;
    if (mat_lit.blockMapId > 0) {
        isWater = mat_lit.blockMapId == BLOCK_WATER;
    }

    // uint2 refract_uv = uint2(refract_texcoord * ap.game.screenSize);

    if (translucent.a > 0.0 && !isWater)
        opaque_color *= RgbToLinear(tint);

    float waterDepthL = 0.0;
    if (ap.camera.fluid == 1) {
        waterDepthL = transDist;
    }
    else if (isWater) {
        float3 opaqueClipPos = float3(refract_texcoord, opaqueDepth) * 2.0 - 1.0;
        opaqueViewPos = project(ap.camera.projectionInv, opaqueClipPos);
        float opaqueDist = length(opaqueViewPos);

        waterDepthL = max(opaqueDist - transDist, 0.0);
    }

    half3 opaqueWaterTint = half3(exp(-(waterDepthL + EPSILON) * Water_AbsorbColor));

    if (ap.camera.fluid == 0 && waterDepthL > 0.0) {
        opaque_color *= opaqueWaterTint;

        // opaque_color += fma(opaque_color, half3(1.0 - waterColor.a), waterColor.rgb);
    }

    half3 final_color = fma(opaque_color, half3(1.0 - translucent.a), translucent.rgb);

    if (ap.camera.fluid == 1) {
        final_color *= opaqueWaterTint;
    }
    
    final_color.rgb += weather.rgb * half3(0.25);

    return half4(final_color, half2(1.0).x);
}
