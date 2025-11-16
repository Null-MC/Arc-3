import aperture;
import buffers.ObjectData;
import lib.common;
import lib.material.pbr;
import lib.material.rough_normal;
import lib.light.fresnel;
import lib.sampling.depth;
import lib.sampling.IGN;
import lib.sky.common;
import lib.sky.sample_final;
import lib.dda;

extern static const bool Reflect_Rough;

Sampler2D<float> solidDepthTex;
Sampler2D<half3> texSource;

Sampler2D<half4> texAlbedoGB;
Sampler2D<uint2> texNormalGB;
Sampler2D<uint2> texMatLightGB;


[[shader("fragment")]]
half4 applyReflections(float2 pos : SV_Position) : SV_Target0 {
    uint2 uv = uint2(pos);
    float depth = solidDepthTex[uv];
    half3 finalColor = texSource[uv];
    
    if (depth < 1.0) {
        float2 texcoord = pos / ap.game.screenSize;
        if (TAA_Enabled) texcoord += scene[0].taa_jitter;

        float3 screenPos = float3(texcoord, depth);
        float3 clipPos = screenPos * 2.0 - 1.0;
        float3 viewPos = project(ap.camera.projectionInv, clipPos);
        float3 localPos = mul3(ap.camera.viewInv, viewPos);

        half4 colorData = texAlbedoGB[uv];

        half3 tex_normal = ObjectData_Normals.unpackTex(texNormalGB[uv].g);

        ObjectData_MatLit mat_lit;
        mat_lit.unpack(texMatLightGB[uv]);

        half3 albedo = RgbToLinear(colorData.rgb);
        half roughness = mat_roughness(mat_lit.specular.r);
        half f0_metal = mat_f0_metal(mat_lit.specular.g);
        half metalness = (half)mat_metalness(f0_metal);

        half lmcoord_y = pow2(mat_lit.lmcoord.y);
        half roughL = pow2(roughness);

        float dither = InterleavedGradientNoiseTime(pos);

        // get reflection direction
        float3 reflectNormal = Reflect_Rough
            ? randomizeNormal(uv, tex_normal, roughL)
            : tex_normal;
        
        float viewDist = length(viewPos);
        float3 viewDir = viewPos / viewDist;
        float3 viewNormal = mul(float3x3(ap.camera.view), reflectNormal);
        float3 reflect_viewDir = reflect(viewDir, viewNormal);
        float3 reflect_localDir = mul(float3x3(ap.camera.viewInv), reflect_viewDir);

        float3 reflect_viewPos = 0.5 * viewDist * reflect_viewDir + viewPos;
        float3 reflect_clipPos = project(ap.camera.projection, reflect_viewPos);
        float3 reflect_screenPos = reflect_clipPos * 0.5 + 0.5;

        float3 screenDir = normalize(reflect_screenPos - screenPos);

        // project the reflected trace direction to edge of trace bounds
        float3 screenEnd = projectToScreenBounds(screenPos, screenDir);
        float3 traceClipEnd = screenEnd * 2.0 - 1.0;
        float3 traceClipStart = clipPos;

        float3 traceClipPos;
        float3 traceClipPos_prev = traceClipStart;
        float2 traceScreenPos;

        const uint SS_StepCount = 24;
        const uint SS_RefineSteps = 8;

        bool hit = false;
        float traceDepthL_prev = linearizeDepth(traceClipStart.z, ap.camera.near, ap.camera.far);
        for (uint i = 1; i < SS_StepCount; i++) {
            float f = (i + dither) / SS_StepCount;
            traceClipPos = lerp(traceClipStart, traceClipEnd, f);
            traceScreenPos = traceClipPos.xy * 0.5 + 0.5;
            if (!all(saturate(traceScreenPos) == traceScreenPos)) break;

            float sampleClipDepth = solidDepthTex.Sample(traceScreenPos) * 2.0 - 1.0;
            float screenDepthL = linearizeDepth(sampleClipDepth, ap.camera.near, ap.camera.far);
            float traceDepthL = linearizeDepth(traceClipPos.z, ap.camera.near, ap.camera.far);

            if (screenDepthL < traceDepthL) {
                hit = true;
                break;
            }

            traceClipPos_prev = traceClipPos;
            traceDepthL_prev = traceDepthL;
        }

        if (hit) {
            traceClipStart = traceClipPos_prev;
            traceClipEnd = traceClipPos;

            // traceDepthL_prev = linearizeDepth(traceClipStart.z, ap.camera.near, ap.camera.far);
            for (uint i = 0; i < SS_RefineSteps; i++) {
                float f = (i + dither) / SS_RefineSteps;
                traceClipPos = lerp(traceClipStart, traceClipEnd, f);
                traceScreenPos = traceClipPos.xy * 0.5 + 0.5;
                if (!all(saturate(traceScreenPos) == traceScreenPos)) break;

                float sampleClipDepth = solidDepthTex.Sample(traceScreenPos) * 2.0 - 1.0;
                float screenDepthL = linearizeDepth(sampleClipDepth, ap.camera.near, ap.camera.far);
                float traceDepthL = linearizeDepth(traceClipPos.z, ap.camera.near, ap.camera.far);

                if (screenDepthL < traceDepthL) {
                    break;
                }
            }
        }

        half3 reflectColor;

        if (hit) {
            reflectColor = texSource.Sample(traceScreenPos);
        }
        else {
            reflectColor = sampleSkyFinal(localPos, reflect_localDir, true);
            reflectColor *= lmcoord_y;
        }

        half3 f0 = lerp(half3(f0_metal), albedo.rgb, metalness);

        half3 localDir = half3(normalize(localPos));
        half NoVm = max(dot(reflectNormal, -localDir), (half)0.0);
        half3 F_NoV = F_schlickRough(NoVm, f0, roughL);
        half3 specular_tint = lerp((half)1.0, albedo, metalness);

        // imgDebug[uv] = float4(LinearToRgb(reflectColor * 0.008), 1.0);

        finalColor += F_NoV * ((half)1.0 - roughL) * reflectColor * specular_tint;
    }

    return half4(finalColor, (half)1.0);
}
