import aperture;
import buffers.ObjectData;
import lib.common;
import lib.material.pbr;
import lib.water.wetness;

extern static const int MaxFrames;

Sampler2D<float> texDepth;
Sampler2D<half3> texSource;
Sampler2D<half4> texSource_prev;
Sampler2D<half3> texReprojection;

Sampler2D<uint2> texMatLightGB;
Sampler2D<half2> texWetnessGB;


[[shader("fragment")]]
half4 accumulateReflections(float2 pos : SV_Position) : SV_Target0 {
    uint2 uv = uint2(pos);
    float depth = texDepth[uv];

    half3 color = half3(0.0);
    half counter = 0;
    
    if (depth < 1.0) {
        float3 reproj = texReprojection[uv];
        float2 texcoord = pos / float2(ap.game.screenSize);
        
        float2 prev_texcoord = texcoord + reproj.xy;
        // if (TAA_Enabled) texcoord -= scene[0].taa_jitter_prev;
        half4 color_prev = texSource_prev.Sample(prev_texcoord);

        ObjectData_MatLit mat_lit;
        mat_lit.unpackSpecular(texMatLightGB[uv].r);
        half roughness = mat_roughness(mat_lit.specular.r);

        if (World_HasSky) {
            half2 wetness_puddle = texWetnessGB[uv];
            Wetness_ApplyRoughness(roughness, wetness_puddle.x);
        }

        float roughL = pow2(roughness);

        float _maxFrames = lerp(2.0, float(MaxFrames), roughL);
        counter = clamp(color_prev.a * step(0.6, reproj.z), 0, _maxFrames) + 1;

        color = texSource.Sample(texcoord);
        color = lerp(color_prev.rgb, color, rcp(counter));
    }

    return half4(color, counter);
}
