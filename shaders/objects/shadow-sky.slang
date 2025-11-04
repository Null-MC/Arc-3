import aperture;
import lib.common;

extern static const bool ALPHATEST_ENABLED = false;


struct VertexOutput {
    float4 position : SV_Position;

    float2 uv;
    nointerpolation uint color;
    nointerpolation int blockId;
};

[[shader("vertex")]]
VertexOutput vertexMain(Vertex input) {
    VertexOutput output;
    
    half4 color = input.color();
    output.uv = input.uv();

    output.blockId = -1;
    if (let value = input.blockId()) output.blockId = value;

    float3 modelPos = input.pos().xyz;
    float3 shadowViewPos = mul3(input.viewMatrix(), modelPos);
    output.position = mul(input.projectionMatrix(), float4(shadowViewPos, 1.0));

    if (output.blockId >= 0 && ap.blocks[output.blockId].isFluid) {
        color = half4(1.0);
    }

    output.color = packUnorm4x8(color);

    return output;
}


[[shader("fragment")]]
float4 fragmentMain(VertexOutput input) : SV_Target0 {
    float4 color = 0;

    if (input.blockId >= 0 && ap.blocks[input.blockId].isFluid) {
        color = float4(1.0, 1.0, 1.0, 0.02);
    }
    else if (ALPHATEST_ENABLED) {
        half4 tint = unpackUnorm4x8ToHalf(input.color);
        color = albedoTex.Sample(input.uv) * tint;
        iris_discardIfNeeded(color);

        color.rgb = RgbToLinear(color.rgb);
        color.rgb = lerp(color.rgb, 0.0, pow2(color.a));
        color.rgb = LinearToRgb(color.rgb);
    }

    return color;
}
