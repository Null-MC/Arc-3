import aperture;
import buffers.OpaqueObject;
import lib.common;
import lib.material.pbr;
import lib.point_lights;
import lib.light.floodfill;
import lib.light.hand;
import lib.octohedral;

extern static const bool PointLight_Enabled;
extern static const bool FloodFill_Enabled;

Sampler2D<float> solidDepthTex;

Sampler2D<half4> texAlbedoGB;
Sampler2D<uint2> texNormalGB;
Sampler2D<uint2> texMatLightGB;


struct FragmentOutput {
    half3 diffuse : SV_Target0;
    half3 specular : SV_Target1;
};

[[shader("fragment")]]
FragmentOutput lightingBlockHand(float2 pos : SV_Position) {
    FragmentOutput output;
    output.diffuse = half3(0.0);
    output.specular = half3(0.0);

    uint2 uv = uint2(pos);

    half4 colorData = texAlbedoGB[uv];

    OpaqueObject_Normals normals;
    normals.unpack(texNormalGB[uv]);

    OpaqueObject_MatLit mat_lit;
    mat_lit.unpack(texMatLightGB[uv]);

    float lmcoord_x = pow2(mat_lit.lmcoord.r);

    float depth = solidDepthTex[uv];
    if (depth < 1.0) {
        float2 texcoord = pos / ap.game.screenSize;
        if (TAA_Enabled) texcoord -= scene[0].taa_jitter;

        float3 clipPos = float3(texcoord, depth) * 2.0 - 1.0;
        float3 viewPos = project(ap.camera.projectionInv, clipPos);
        float3 localPos = mul3(ap.camera.viewInv, viewPos);

        if (PointLight_Enabled) {
            if (shadowPoint_isInBounds(localPos)) {
                lmcoord_x = 0.0;
            }
        }

        // FloodFill
        if (FloodFill_Enabled) {
            float3 lpvPos = FloodFill_GetBufferPosition(localPos);
            lpvPos -= normals.geo * 0.25;
            lpvPos += normals.tex * 0.75;
            
            if (FloodFill_InBounds(lpvPos)) {
                output.diffuse += floodfill_sample(lpvPos) * BLOCK_LUX;
                lmcoord_x = 0.0;
            }
        }

        output.diffuse += lmcoord_x * BLOCK_LUX;

        // Hand Lights
        float3 handSampleLocalPos = normals.geo*0.02 + localPos;
        float3 viewDir = -normalize(localPos);
        
        half3 albedo = RgbToLinear(colorData.rgb);
        float roughness = mat_roughness(mat_lit.specular.r);
        float f0_metal = mat_f0_metal(mat_lit.specular.g);
        float metalness = mat_metalness(f0_metal);

        half3 f0 = lerp(f0_metal, albedo, metalness);
        float roughL = roughness*roughness;

        if (ap.game.mainHand != 0u) {
            float3 lightLocalPos = GetHandLightPos(HandLightOffset_main);
            GetHandLight(output.diffuse, output.specular, ap.game.mainHand, lightLocalPos, handSampleLocalPos, viewDir, normals.tex, normals.geo, f0, roughL);
        }

        if (ap.game.offHand != 0u) {
            float3 lightLocalPos = GetHandLightPos(HandLightOffset_alt);
            GetHandLight(output.diffuse, output.specular, ap.game.offHand, lightLocalPos, handSampleLocalPos, viewDir, normals.tex, normals.geo, f0, roughL);
        }

        output.diffuse /= half3(PI);

        // remove diffuse for smooth metals
        float smoothness = 1.0 - roughness;
        output.diffuse *= 1.0 - metalness * smoothness;
    }

    return output;
}
