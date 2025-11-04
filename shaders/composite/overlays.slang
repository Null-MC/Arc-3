import aperture;
import lib.common;
import lib.sampling.depth;
import lib.water.common;

extern static const int RefractMode;

static const int REFRACTION_STEPS = 16;
static const int Refract_ScreenSpace = 1;

Sampler2D<float> mainDepthTex;
Sampler2D<float> solidDepthTex;

Sampler2D<half3> texSource;
Sampler2D<half4> texFinalTranslucent;
Sampler2D<half3> texNormalTranslucent;
Sampler2D<half3> texTintTranslucent;
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
    half4 translucent = texFinalTranslucent[uv];

    float2 texcoord = pos / ap.game.screenSize;
    if (TAA_Enabled) texcoord -= scene[0].taa_jitter;

    float transDepth = mainDepthTex[uv];

    // float3 opaqueClipPos = float3(texcoord, opaqueDepth) * 2.0 - 1.0;
    // float3 opaqueViewPos = project(ap.camera.projectionInv, opaqueClipPos);
    // // float3 localPos = mul3(ap.camera.viewInv, viewPos);

    float3 transClipPos = float3(texcoord, transDepth) * 2.0 - 1.0;
    float3 transViewPos = project(ap.camera.projectionInv, transClipPos);
    // float3 localPos = mul3(ap.camera.viewInv, viewPos);

    float2 refract_uv = pos / ap.game.screenSize;

    if (RefractMode == Refract_ScreenSpace && translucent.a > 0.0) {
        float3 refract_localNormal = texNormalTranslucent[uv];
        refract_localNormal = normalize(refract_localNormal * 2.0 - 1.0);

        const float IOR_AIR   = 1.0003;
        const float IOR_WATER   = 1.333;
        const float IOR_DEFAULT = 1.5;
        // TODO: store and use actual translucent IOR
        const float ETA_AIR_TO_WATER = (IOR_AIR/IOR_WATER);
        const float ETA_WATER_TO_AIR = 1.02;// (IOR_WATER/IOR_AIR);
        float eta = ap.camera.fluid == 1 ? ETA_WATER_TO_AIR : ETA_AIR_TO_WATER;

        float3 viewDir = normalize(transViewPos);
        float3 refract_viewNormal = mul(float3x3(ap.camera.view), refract_localNormal);
        float3 refract_viewDir = refract(viewDir, refract_viewNormal, eta);

        if (dot(refract_viewDir, refract_viewDir) < EPSILON) refract_uv = -1.0;
        else {
            ss_refract(refract_uv, transViewPos, refract_viewDir);
            refract_uv = saturate(refract_uv);
        }
    }

    // float opaqueDepth = 1.0;
    float3 opaqueViewPos = transViewPos;
    half3 opaque_color = half3(0.0);
    if (all(refract_uv >= 0.0)) {
        float opaqueDepth = solidDepthTex.Sample(refract_uv);
        float3 opaqueClipPos = float3(refract_uv, opaqueDepth) * 2.0 - 1.0;
        opaqueViewPos = project(ap.camera.projectionInv, opaqueClipPos);
        // float3 localPos = mul3(ap.camera.viewInv, viewPos);

        opaque_color = texSource.Sample(refract_uv);
        opaque_color *= RgbToLinear(tint);
    }

    bool isWater = true; // TODO
    float dist_near = length(transViewPos);
    float dist_far = length(opaqueViewPos);

    if (ap.camera.fluid == 0 && isWater) {
        float len_far = max(dist_far - dist_near, 0.0) + EPSILON;
        opaque_color *= half3(exp(-len_far * Water_AbsorbColor));
    }

    // half3 final_color = lerp(opaque_color, translucent.rgb, translucent.a);
    half3 final_color = fma(opaque_color, half3(1.0 - translucent.a), translucent.rgb);

    if (ap.camera.fluid == 1) {
        float len_near = dist_near + EPSILON;
        final_color *= half3(exp(-len_near * Water_AbsorbColor));
    }
    
    final_color.rgb += weather.rgb * half3(0.25);

    return half4(final_color, half2(1.0).x);
}
