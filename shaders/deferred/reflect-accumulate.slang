import aperture;
import buffers.ObjectData;
import lib.common;
import lib.material.pbr;

extern static const int MaxFrames;

Sampler2D<float> texDepth;
Sampler2D<half3> texSource;
Sampler2D<half4> texSource_prev;
Sampler2D<half3> texReprojection;

Sampler2D<uint2> texMatLightGB;


[[shader("fragment")]]
half4 accumulateReflections(float2 pos : SV_Position) : SV_Target0 {
    uint2 uv = uint2(pos);
    float depth = texDepth[uv];

    float3 color = 0.0;
    float counter = 0.0;
    
    if (depth < 1.0) {
        float3 reproj = texReprojection[uv];
        float2 texcoord = pos / float2(ap.game.screenSize);
        
        float2 prev_texcoord = texcoord + reproj.xy;
        // if (TAA_Enabled) texcoord -= scene[0].taa_jitter_prev;
        float4 color_prev = texSource_prev.Sample(prev_texcoord);

        ObjectData_MatLit mat_lit;
        mat_lit.unpackSpecular(texMatLightGB[uv].r);
        float roughness = mat_roughness(mat_lit.specular.r);
        float roughL = pow2(roughness);

        float _maxFrames = lerp(2.0, float(MaxFrames), roughL);
        counter = clamp(color_prev.a * step(0.6, reproj.z), 0, _maxFrames);

        color = texSource.Sample(texcoord);
        color = lerp(color_prev.rgb, color, rcp(counter + 1.0));
    }

    return half4(float4(color, counter + 1.0));
}
