import aperture;
import buffers.ObjectData;
import lib.common;

extern static const int GI_MaxFrames;
// extern static const int BufferWidth;
// extern static const int BufferHeight;
// extern static const int BufferScale;

// static const float2 BufferSize = float2(BufferWidth, BufferHeight);

Sampler2D<float> texDepth;
Sampler2D<half3> texSource;
// Sampler2D<half3> texGI;
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
        // counter = clamp(gi_prev.a, 0, GI_MaxFrames);

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
