import aperture;
import buffers.ObjectData;
import lib.common;
import lib.material.pbr;
import lib.material.rough_normal;
import lib.light.fresnel;
import lib.sampling.depth;
import lib.noise.IGN;
import lib.sky.common;
import lib.sky.sample_final;
import lib.screen_trace;

extern static const int BufferWidth;
extern static const int BufferHeight;
extern static const int BufferScale;

static const int2 BufferSize = int2(BufferWidth, BufferHeight);

extern static const int RefractMode;
extern static const bool Reflect_Rough;
extern static const int Reflect_ScreenSteps;
extern static const int Reflect_RefineSteps;

Sampler2D<float> mainDepthTex;
Sampler2D<half3> texSource;

Sampler2D<half4> texAlbedoGB_translucent;
Sampler2D<uint2> texNormalGB_translucent;
Sampler2D<uint2> texMatLightGB_translucent;


[[shader("fragment")]]
half4 applyReflections(float2 pos : SV_Position) : SV_Target0 {
    uint2 uv_full = uint2(pos) * BufferScale;
    float depth = mainDepthTex[uv_full];
    half3 finalColor = half3(0.0);

    half4 colorData = texAlbedoGB_translucent[uv_full];
    
    if (colorData.a > 0.0) {
        float2 texcoord = (uv_full + 0.5) / ap.game.screenSize;
        // if (TAA_Enabled) texcoord -= scene[0].taa_jitter;

        float3 screenPos = float3(texcoord, depth);
        float3 clipPos = screenPos * 2.0 - 1.0;
        float3 viewPos = project(ap.camera.projectionInv, clipPos);
        float3 localPos = mul3(ap.camera.viewInv, viewPos);

        uint normalDataG = texNormalGB_translucent[uv_full].g;
        half3 tex_normal = ObjectData_Normals.unpackTex(normalDataG);

        ObjectData_MatLit mat_lit;
        mat_lit.unpack(texMatLightGB_translucent[uv_full]);

        half3 albedo = RgbToLinear(colorData.rgb);
        half roughness = mat_roughness(mat_lit.specular.r);
        half f0_metal = mat_f0_metal(mat_lit.specular.g);
        half metalness = (half)mat_metalness(f0_metal);

        half lmcoord_y = pow2(mat_lit.lmcoord.y);
        half roughL = pow2(roughness);

        float dither = IGN_TAA(pos);

        float3 reflectNormal = Reflect_Rough
            ? randomizeNormal(int2(pos), tex_normal, roughL)
            : tex_normal;
        
        // float viewDist = length(viewPos);
        // float3 viewDir = viewPos / viewDist;
        float3 viewDir = normalize(viewPos);
        float3 viewNormal = mul(float3x3(ap.camera.view), reflectNormal);
        float3 reflect_viewDir = reflect(viewDir, viewNormal);
        float3 reflect_localDir = mul(float3x3(ap.camera.viewInv), reflect_viewDir);

        float3 screenEnd = projectScreenTrace(viewPos, screenPos, reflect_viewDir);
        float3 traceClipEnd = screenEnd * 2.0 - 1.0;
        float3 traceClipStart = clipPos;

        float3 traceClipPos;
        float3 traceClipPos_prev = traceClipStart;
        float2 traceScreenPos = 0.0;

        bool hit = false;
        float traceDepthL_prev = linearizeDepth(traceClipStart.z, ap.camera.near, ap.camera.far);
        for (uint i = 0; i < Reflect_ScreenSteps; i++) {
            float f = (i + dither) / Reflect_ScreenSteps;
            traceClipPos = lerp(traceClipStart, traceClipEnd, saturate(f));
            float2 samplePos = traceClipPos.xy * 0.5 + 0.5;
            if (!all(saturate(samplePos) == samplePos)) break;

            float sampleClipDepth = mainDepthTex.Sample(samplePos) * 2.0 - 1.0;
            float screenDepthL = linearizeDepth(sampleClipDepth, ap.camera.near, ap.camera.far);
            float traceDepthL = linearizeDepth(traceClipPos.z, ap.camera.near, ap.camera.far);

            if (screenDepthL < traceDepthL) {
                hit = true;
                break;
            }

            traceScreenPos = samplePos;
            traceClipPos_prev = traceClipPos;
            traceDepthL_prev = traceDepthL;
        }

        if (hit) {
            traceClipStart = traceClipPos_prev;
            traceClipEnd = traceClipPos;
            traceScreenPos = traceClipPos_prev.xy * 0.5 + 0.5;

            for (uint i = 0; i < Reflect_RefineSteps; i++) {
                float f = (i + dither) / Reflect_RefineSteps;
                traceClipPos = lerp(traceClipStart, traceClipEnd, saturate(f));
                float2 samplePos = traceClipPos.xy * 0.5 + 0.5;
                if (!all(saturate(samplePos) == samplePos)) break;

                float sampleClipDepth = mainDepthTex.Sample(samplePos) * 2.0 - 1.0;
                float screenDepthL = linearizeDepth(sampleClipDepth, ap.camera.near, ap.camera.far);
                float traceDepthL = linearizeDepth(traceClipPos.z, ap.camera.near, ap.camera.far);

                if (screenDepthL < traceDepthL) {
                    break;
                }

                traceScreenPos = samplePos;
            }
        }

        half3 reflectColor;

        if (hit && all(traceScreenPos > 0.0)) {
            // traceScreenPos = saturate(traceScreenPos);
            reflectColor = texSource.Sample(traceScreenPos);
        }
        else {
            half3 skyColor = sampleSkyFinal(localPos, reflect_localDir, true);
            reflectColor = skyColor * lmcoord_y;
        }

        half3 f0 = lerp(half3(f0_metal), albedo.rgb, metalness);

        half3 localDir = half3(normalize(localPos));
        half NoVm = max(dot(reflectNormal, -localDir), (half)0.0);
        half3 F_NoV = F_Lazanyi2019(NoVm, f0);
        half3 specular_tint = lerp((half)1.0, albedo, metalness);

        // imgDebug[uv] = float4(LinearToRgb(reflectColor * 0.008), 1.0);

        finalColor += F_NoV * ((half)1.0 - roughL) * reflectColor * specular_tint;
    }

    return half4(finalColor, (half)1.0);
}
