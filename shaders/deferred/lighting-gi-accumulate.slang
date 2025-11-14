import aperture;
import buffers.ObjectData;
import lib.common;

static const float GI_MaxFrames = 60;

Sampler2D<float> texDepth;
Sampler2D<half3> texSource;
Sampler2D<half4> texGI_prev;
Sampler2D<half3> texReprojection;


[[shader("fragment")]]
half4 accumulateGI(float2 pos : SV_Position) : SV_Target0 {
    uint2 uv = uint2(pos);
    float depth = texDepth[uv];
    half3 diffuse = half3(0.0);
    float counter = 0.0;
    
    if (depth < 1.0) {
        // float2 texcoord = pos / ap.game.screenSize;
        // if (TAA_Enabled) texcoord -= scene[0].taa_jitter;

        diffuse = texSource[uv];

        float3 reproj = texReprojection[uv];
        float2 prev_texcoord = (pos) / ap.game.screenSize + reproj.xy;
        float4 gi_prev = texGI_prev.Sample(prev_texcoord);

        counter = clamp(gi_prev.a * step(0.6, reproj.z), 0, GI_MaxFrames);
        diffuse = lerp(gi_prev.rgb, diffuse, rcp(counter + 1.0));
    }

    // DEBUG
    // imgDebug[uv] = half4(texSource[uv] * 0.02, (half)1.0);
    imgDebug[uv] = half4(diffuse * 0.02, (half)1.0);

    return half4(diffuse, (half)(counter + 1.0));
}
