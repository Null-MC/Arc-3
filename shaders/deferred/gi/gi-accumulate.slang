import aperture;
import buffers.ObjectData;
import lib.common;
import lib.sky.sample_irradiance;

extern static const int GI_MaxFrames;

Sampler2D<float> texDepth;
Sampler2D<half3> texSource;
Sampler2D<uint2> texNormalGB;
Sampler2D<uint2> texMatLightGB;

Sampler2D<half4> texGI_prev;
Sampler2D<half3> texReprojection;


[[shader("fragment")]]
half4 accumulateGI(float2 pos : SV_Position) : SV_Target0 {
    // uint2 uv = uint2(pos);
    // float2 texcoord = pos / BufferSize;
    uint2 uv = uint2(pos);
    float depth = texDepth[uv];
    float3 diffuse = 0.0;
    float counter = 0.0;
    
    if (depth < 1.0) {
        float3 reproj = texReprojection[uv];
        float2 texcoord = pos / float2(ap.game.screenSize);
        
        float2 prev_texcoord = texcoord + reproj.xy;
        // if (TAA_Enabled) texcoord -= scene[0].taa_jitter_prev;
        float4 gi_prev = texGI_prev.Sample(prev_texcoord);

        counter = clamp(gi_prev.a * step(0.6, reproj.z), 0, GI_MaxFrames);

        if (counter < EPSILON) {
            float3 tex_normal = ObjectData_Normals.unpackTex(texNormalGB[uv].g);

            ObjectData_MatLit mat_lit;
            mat_lit.unpackLightOcclusion(texMatLightGB[uv].g);
            half lmcoord_y = pow2(mat_lit.lmcoord.y);

            // fallback default GI to sky irradiance
            gi_prev.rgb = sampleSkyIrradiance(tex_normal) * lmcoord_y;
        }

        diffuse = texSource.Sample(texcoord);
        // diffuse = texSource[uv / BufferScale];
        // TODO:  try mixing atrous with raw sample based on history
        // diffuse = lerp(texGI[uv], diffuse, rcp(1.0 + counter));
        
        diffuse = lerp(gi_prev.rgb, diffuse, rcp(counter + 1.0));
    }

    // DEBUG
    imgDebug[uint2(pos)] = half4(diffuse * 0.02, (half)1.0);

    return half4(diffuse, (half)(counter + 1.0));
}
