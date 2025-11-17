import aperture;
import buffers.ObjectData;
import lib.common;

extern static const int GI_MaxFrames;
extern static const int BufferWidth;
extern static const int BufferHeight;

static const float2 BufferSize = float2(BufferWidth, BufferHeight);

Sampler2D<float> texDepth;
Sampler2D<half3> texSource;
// Sampler2D<half3> texGI;
Sampler2D<half4> texGI_prev;
Sampler2D<half3> texReprojection;


[[shader("fragment")]]
half4 accumulateGI(float2 pos : SV_Position) : SV_Target0 {
    // uint2 uv = uint2(pos);
    float2 texcoord = pos / BufferSize;
    float depth = texDepth.Sample(texcoord);
    half3 diffuse = half3(0.0);
    float counter = 0.0;
    
    if (depth < 1.0) {
        float3 reproj = texReprojection.Sample(texcoord);
        float2 prev_texcoord = (pos) / BufferSize + reproj.xy;
        float4 gi_prev = texGI_prev.Sample(prev_texcoord);

        counter = clamp(gi_prev.a * step(0.6, reproj.z), 0, GI_MaxFrames);

        diffuse = texSource.Sample(texcoord);
        // TODO:  try mixing atrous with raw sample based on history
        // diffuse = lerp(texGI[uv], diffuse, rcp(1.0 + counter));
        
        diffuse = lerp(gi_prev.rgb, diffuse, rcp(counter + 1.0));
    }

    // DEBUG
    // imgDebug[uv] = half4(texSource[uv] * 0.02, (half)1.0);
    imgDebug[uint2(pos)] = half4(diffuse * 0.02, (half)1.0);

    return half4(diffuse, (half)(counter + 1.0));
}
