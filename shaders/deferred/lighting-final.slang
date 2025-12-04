import aperture;
import buffers.ObjectData;
import lib.common;
import lib.material.pbr;
import lib.water.wetness;
import lib.sky.sample_final;

extern static const bool Lighting_GI = false;
extern static const bool RENDER_TRANSLUCENT = false;

Sampler2D<float> texDepth;

Sampler2D<half4> texAlbedoGB;
Sampler2D<uint2> texMatLightGB;

Sampler2D<half> texWetnessGB;
Sampler2D<half3> texDiffuse;
Sampler2D<half3> texSpecular;
Sampler2D<half3> texGI_final;


[[shader("fragment")]]
half4 lightingFinal(float2 pos : SV_Position) : SV_Target0 {
    uint2 uv = uint2(pos);
    float depth = texDepth[uv];
    half4 albedo = texAlbedoGB[uv];

    float2 texcoord = pos / ap.game.screenSize;

    half4 final = half4(0.0);
    if (depth < 1.0 && albedo.a > 0.0) {
        ObjectData_MatLit mat_lit;
        mat_lit.unpack(texMatLightGB[uv]);

        half wetness = texWetnessGB[uv];
        half3 diffuse = texDiffuse.Sample(texcoord);
        half3 specular = texSpecular.Sample(texcoord);

        if (Lighting_GI && !RENDER_TRANSLUCENT) {
            // DEBUG
            // imgDebug[uint2(pos)] = half4(diffuse * 0.08, (half)1.0);
            
            half3 gi = texGI_final.Sample(texcoord);
            diffuse += gi * mat_lit.occlusion;
        }
        
        half roughness = mat_roughness(mat_lit.specular.r);
        half f0_metal = mat_f0_metal(mat_lit.specular.g);
        half emission = mat_emission(mat_lit.specular);
        half metalness = mat_metalness(f0_metal);
        half porosity = mat_porosity(mat_lit.specular.b, roughness, f0_metal);

		ApplyInputTransform(albedo.rgb);
        
        // TODO: wetness
        Wetness_ApplyRoughness(roughness, wetness);

        // half3 ambient = 0.0;// (half)0.2 * mat_lit.occlusion;
        // diffuse += ambient;

        // remove diffuse for smooth metals
        half smoothness = (half)1.0 - pow2(roughness);
        diffuse *= (half)1.0 - metalness * smoothness;

        // diffuse += emission * BLOCK_LUX;
        final.rgb += albedo.rgb * emission * BLOCK_LUM;

        if (Debug_WhiteWorld) albedo.rgb = WhiteWorldColor;

        float3 diffColor = Wetness_GetAlbedo(albedo.rgb, porosity, wetness);
        half3 specularTint = mat_specularTint(albedo.rgb, f0_metal, metalness);

        final.rgb += diffColor * diffuse + specular * specularTint;
        final.a = albedo.a;
    }
    else if (!RENDER_TRANSLUCENT && World_HasSky) {
        // float2 texcoord = pos / ap.game.screenSize;
        float2 project_coord = texcoord;
        if (TAA_Enabled) project_coord += scene[0].taa_jitter;

        float3 clipPos = float3(project_coord, depth) * 2.0 - 1.0;
        // float3 viewPos = project(ap.camera.projectionInv, clipPos);
        // float3 localPos = mul3(ap.camera.viewInv, viewPos);
        float3 localPos = project(scene[0].viewProjectionInv, clipPos);
        float3 viewLocalDir = normalize(localPos);

        final.rgb = sampleSkyFinal(localPos, viewLocalDir, false);
        // final.rgb = ACES_linear_to_cg(final.rgb); // TODO: this should probably be earlier in lut chain
        final.a = (half)1.0;
    }

    return final;
}
