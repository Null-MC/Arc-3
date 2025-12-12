import aperture;
import buffers.ObjectData;
import lib.common;
import lib.blocks;
import lib.material.pbr;
import lib.light.floodfill_sky;
import lib.water.wetness;
import lib.sampling.dfd_normal;

extern static const bool RENDER_TRANSLUCENT = false;

Sampler2D<float> texDepth;
Sampler2D<half2> texPuddles;
Sampler2D<half> texWaterWaves_high;

Sampler2D<half4> texAlbedoGB;
Sampler2D<uint2> texNormalGB;
Sampler2D<uint2> texMatLightGB;

Sampler2D<uint2> texMatLightGB_translucent;


struct FragmentOutput {
    half2 wetness_puddle : SV_Target0;
    uint2 normals : SV_Target1;
    // uint2 mat_light : SV_Target2;
};

[[shader("fragment")]]
FragmentOutput skyWetness(float2 pos : SV_Position) {
    float wetnessF = 0.0;
    float puddleF = 0.0;

    uint2 uv = uint2(pos);
    float depth = texDepth[uv];
    half4 colorData = texAlbedoGB[uv];

    ObjectData_Normals normals;
    normals.unpack(texNormalGB[uv]);
    
    if (depth < 1.0 && colorData.a > 0.0) {
        float2 texcoord = pos / ap.game.screenSize;
        if (TAA_Enabled) texcoord -= scene[0].taa_jitter;

        float3 clipPos = float3(texcoord, depth) * 2.0 - 1.0;
        float3 localPos = project(scene[0].viewProjectionInv, clipPos);

        ObjectData_MatLit mat_lit;
        mat_lit.unpack(texMatLightGB[uv]);

        half roughness = mat_roughness(mat_lit.specular.r);
        half f0_metal = mat_f0_metal(mat_lit.specular.g);
        half porosity = mat_porosity(mat_lit.specular.b, roughness, f0_metal);

        //float lmcoord_y = pow2(mat_lit.lmcoord.y);

        const float3 worldUp = float3(0.0, 1.0, 0.0);

        float NoL = dot(normals.tex, worldUp);
        float NoLm_wrap = max((NoL + porosity) / (1.0 + porosity), 0.0);

        float geo_NoLm = max(dot(normals.geo, worldUp), 0.0);

        float skyF = smoothstep(0.78, 0.92, mat_lit.lmcoord.y);
        if (FloodFill_Sky_Enabled) {
            float3 bufferPos = FloodFill_Sky_GetBufferPosition(localPos + 0.5*normals.geo);
            if (FloodFill_Sky_InBounds(bufferPos)) {
                float ff_skyF = floodfill_sky_sample(bufferPos);
                skyF = min(skyF, smoothstep(0.5, 1.0, ff_skyF));
                // skyF = smoothstep(0.9, 1.0, skyF);
            }
        }

        // skyF *= NoLm_wrap;
        
        // TODO: expand on this basic idea
        float sky_wetness = (half)(skyF * scene[0].WetnessGround);

        float time = 0.002 * ap.timing.timeElapsed;
        float3 worldPos = localPos + ap.camera.position;
        half2 p1 = texPuddles.Sample(worldPos.xz * 0.09 + time);
        half2 p2 = texPuddles.Sample(worldPos.xz * 0.17 - time);
        half2 puddles = half2(p1.x * p2.x, 0.38*(p1.y + p2.y));

        float puddleThreshold_min = 1.0 - settings.Sky_PuddleThreshold;
        float puddleThreshold_max = puddleThreshold_min + (0.08*porosity + 0.02);

        puddleF = lerp(puddles.y, puddles.x, porosity) * sky_wetness * geo_NoLm;
        wetnessF = saturate(unmix(0.0, puddleThreshold_min, puddleF)*0.6 + 0.4*sky_wetness) * NoLm_wrap;
        puddleF = smoothstep(puddleThreshold_min, puddleThreshold_max, puddleF);

        wetnessF = max(wetnessF * porosity, puddleF);

        // float absorbed_puddle = max(puddles.x - 0.5*(1.0 - scene[0].WetnessGround), 0.0);
        // puddleF -= 0.5*(1.0 - scene[0].WetnessGround);
        // puddleF = saturate(puddleF * 20.0);


        // wetnessF *= (puddles.x * 0.5 + 0.5) * porosity;

        // puddleF = saturate((wetnessF - 1.0) * 20.0);
        // wetnessF = saturate(wetnessF);

        // Make opaque surfaces under water fully wet
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

        float n1 = texWaterWaves_high.Sample(worldPos.xz * 0.57 - 60.0*time);
        float n2 = texWaterWaves_high.Sample(worldPos.xz * 0.53 + 60.0*time);

        float puddleHeight = 0.02 * sqrt(puddleF) + 0.06 * (n1 * n2) * ap.world.rainStrength;
        float3 puddlePos = puddleHeight * normals.geo + localPos;
        float3 puddle_normal = getSurfaceNormal(puddlePos, normals.geo);
        puddle_normal = normalize(lerp(puddle_normal, normals.geo, porosity));
        
        // Wetness_ApplyNormal(normals.tex, puddle_normal, puddleF);

        normals.tex = (half3)lerp(normals.tex, puddle_normal, puddleF);
        normals.tex = normalize(normals.tex);

        // mat_lit.specular.r = 1.0 - roughness;
    }

    FragmentOutput output;
    output.wetness_puddle = half2(wetnessF, puddleF);
    output.normals = normals.pack();
    // output.mat_light = mat_lit.pack();
    return output;
}
