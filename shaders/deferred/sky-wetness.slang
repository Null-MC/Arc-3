import aperture;
import buffers.ObjectData;
import lib.common;
import lib.blocks;
import lib.material.pbr;

extern static const bool RENDER_TRANSLUCENT = false;

Sampler2D<float> texDepth;

Sampler2D<half4> texAlbedoGB;
Sampler2D<uint2> texNormalGB;
Sampler2D<uint2> texMatLightGB;

Sampler2D<uint2> texMatLightGB_translucent;


[[shader("fragment")]]
half2 skyWetness(float2 pos : SV_Position) : SV_Target0 {
    float wetnessF = 0.0;
    float puddleF = 0.0;

    uint2 uv = uint2(pos);
    float depth = texDepth[uv];
    half4 colorData = texAlbedoGB[uv];
    
    if (depth < 1.0 && colorData.a > 0.0) {
        // float2 texcoord = pos / ap.game.screenSize;
        // if (TAA_Enabled) texcoord -= scene[0].taa_jitter;

        // float3 clipPos = float3(texcoord, depth) * 2.0 - 1.0;
        // float3 localPos = project(scene[0].viewProjectionInv, clipPos);

        ObjectData_Normals normals;
        normals.unpack(texNormalGB[uv]);

        ObjectData_MatLit mat_lit;
        mat_lit.unpack(texMatLightGB[uv]);

        half roughness = mat_roughness(mat_lit.specular.r);
        half f0_metal = mat_f0_metal(mat_lit.specular.g);
        half porosity = mat_porosity(mat_lit.specular.b, roughness, f0_metal);

        //float lmcoord_y = pow2(mat_lit.lmcoord.y);

        float NoL = dot(normals.tex, float3(0.0, 1.0, 0.0));
        float NoLm_wrap = max((NoL + porosity) / (1.0 + porosity), 0.0);
        float skyF = smoothstep(0.70, 0.92, mat_lit.lmcoord.y) * NoLm_wrap;
        
        // TODO: expand on this basic idea
        wetnessF = (half)(skyF * ap.world.rainStrength);

        if (!RENDER_TRANSLUCENT) {
            ObjectData_MatLit mat_lit;
            mat_lit.unpackLightOcclusion(texMatLightGB_translucent[uv].g);

            if (ap.camera.fluid == 1) {
                if (mat_lit.blockMapId != BLOCK_WATER) {
                    wetnessF = 1.0;
                    puddleF = 0.0;
                }
            }
            else {
                if (mat_lit.blockMapId == BLOCK_WATER) {
                    wetnessF = 1.0;
                    puddleF = 0.0;
                }
            }
        }
    }

    return half2(float2(wetnessF, puddleF));
}
