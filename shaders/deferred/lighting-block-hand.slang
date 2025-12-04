import aperture;
import buffers.ObjectData;
import lib.common;
import lib.blocks;
import lib.material.pbr;
import lib.point_lights;
import lib.light.floodfill;
import lib.light.hand;
import lib.water.wetness;

extern static const bool PointLight_Enabled;
extern static const bool FloodFill_Enabled;

Sampler2D<float> texDepth;
Sampler2D<half2> texWetnessGB;

Sampler2D<half4> texAlbedoGB;
Sampler2D<uint2> texNormalGB;
Sampler2D<uint2> texMatLightGB;


struct FragmentOutput {
    half3 diffuse : SV_Target0;
    half3 specular : SV_Target1;
};

[[shader("fragment")]]
FragmentOutput lightingBlockHand(float2 pos : SV_Position) {
    uint2 uv = uint2(pos);
    half4 colorData = texAlbedoGB[uv];
    float depth = texDepth[uv];

    float3 diffuse = 0.0;
    float3 specular = 0.0;

    if (depth < 1.0 && colorData.a > 0.0) {
        ObjectData_Normals normals;
        normals.unpack(texNormalGB[uv]);

        ObjectData_MatLit mat_lit;
        mat_lit.unpack(texMatLightGB[uv]);

        half lmcoord_x = pow2(mat_lit.lmcoord.r);

        float2 texcoord = pos / ap.game.screenSize;
        if (TAA_Enabled) texcoord -= scene[0].taa_jitter;

        float3 ndcPos = float3(texcoord, depth) * 2.0 - 1.0;

        if (mat_lit.blockMapId == BLOCK_HAND) {
            ndcPos.z /= MC_HAND_DEPTH;
        }

        float3 localPos = project(scene[0].viewProjectionInv, ndcPos);

        if (PointLight_Enabled) {
            if (shadowPoint_isInBounds(localPos)) {
                lmcoord_x = (half)0.0;
            }
        }

        // FloodFill
        if (FloodFill_Enabled) {
            float3 lpvPos = FloodFill_GetBufferPosition(localPos);
            lpvPos -= normals.geo * 0.25;
            lpvPos += normals.tex * 0.75;
            
            if (FloodFill_InBounds(lpvPos)) {
                diffuse += floodfill_sample(lpvPos) * BLOCK_LUX;
                lmcoord_x = (half)0.0;
            }
        }

        diffuse += pow2(lmcoord_x) * BLOCK_LUX * BlockLightColor;

        // Hand Lights
        float3 handSampleLocalPos = normals.geo*0.02 + localPos;
        float3 viewDir = -normalize(localPos);
        
        half3 albedo = RgbToLinear(colorData.rgb);
        half roughness = mat_roughness(mat_lit.specular.r);
        half f0_metal = mat_f0_metal(mat_lit.specular.g);
        half metalness = mat_metalness(f0_metal);

        if (World_HasSky) {
            half2 wetness_puddle = texWetnessGB[uv];
            Wetness_ApplyRoughness(roughness, wetness_puddle.x);
            Wetness_ApplyNormal(normals.tex, normals.geo, wetness_puddle.y);
        }

        half3 f0, f82;
        mat_f0(albedo, f0_metal, metalness, f0, f82);
        half roughL = roughness*roughness;

        if (ap.game.mainHand != 0u) {
            float3 lightLocalPos = GetHandLightPos(HandLightOffset_main);
            GetHandLight(diffuse, specular, ap.game.mainHand, lightLocalPos, handSampleLocalPos, viewDir, normals.tex, normals.geo, f0, roughL);
        }

        if (ap.game.offHand != 0u) {
            float3 lightLocalPos = GetHandLightPos(HandLightOffset_alt);
            GetHandLight(diffuse, specular, ap.game.offHand, lightLocalPos, handSampleLocalPos, viewDir, normals.tex, normals.geo, f0, roughL);
        }

        diffuse /= half3(PI);
    }

    FragmentOutput output;
    output.diffuse = half3(diffuse);
    output.specular = half3(specular);
    return output;
}
