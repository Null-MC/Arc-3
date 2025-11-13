import aperture;
import buffers.ObjectData;
import lib.common;
import lib.light.fresnel;
import lib.material.pbr;
import lib.water.water_depth;
import lib.sampling.depth;

// extern static const bool RENDER_TRANSLUCENT = false;
// extern static const half BLOCK_LUX;
extern static const bool Debug_WhiteWorld;

Sampler2D<half3> texDiffuse;
Sampler2D<half3> texSpecular;


[[shader("fragment")]]
half4 lightingFinal(float2 pos : SV_Position) : SV_Target0 {
    uint2 uv = uint2(pos);
    float depthL = WaterDepth_get(uv);
    float depth = delinearizeDepth(depthL, ap.camera.near, ap.camera.far) * 0.5 + 0.5;

    half4 final = half4(0.0);
    if (depth < 1.0) {
        half4 color = texAlbedoGB_water[uv];

        float3 tex_normal = ObjectData_Normals.unpackTex(texNormalGB_water[uv].g);

        ObjectData_MatLit mat_lit;
        mat_lit.unpack(texMatLightGB_water[uv]);

        half3 diffuse = texDiffuse[uv];
        half3 specular = texSpecular[uv];

        half roughness = mat_roughness(mat_lit.specular.r);
        half f0_metal = mat_f0_metal(mat_lit.specular.g);
        // half emission = mat_emission(mat_lit.specular);
        // half metalness = mat_metalness(f0_metal);
        float roughL = pow2(roughness);

        half3 albedo = RgbToLinear(color.rgb);
        // half3 tint = lerp(half3(1.0), albedo, metalness);

        half3 ambient = (half)0.2 * mat_lit.occlusion;
        diffuse += ambient;// + emission * BLOCK_LUX;

        // remove diffuse for smooth metals
        // half smoothness = (half)1.0 - pow2(roughness);
        // diffuse *= (half)1.0 - metalness * smoothness;

        float2 texcoord = pos / ap.game.screenSize;
        if (TAA_Enabled) texcoord -= scene[0].taa_jitter;

        float3 clipPos = float3(texcoord, depth) * 2.0 - 1.0;
        float3 viewPos = project(ap.camera.projectionInv, clipPos);
        float3 localPos = mul3(ap.camera.viewInv, viewPos);
        float3 viewLocalDir = -normalize(localPos);

        float NoVm = max(dot(tex_normal, viewLocalDir), 0.0);
        float F_NoV = F_schlickRough(NoVm, f0_metal, roughL);
        // diffuse *= (half)(1.0 - F_NoV);
        color.a = F_NoV;

        if (Debug_WhiteWorld) albedo = half3(0.85);

        final.rgb = albedo * diffuse + specular;
        final.a = color.a;
    }

    return final;
}
