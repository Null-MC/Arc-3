import aperture;
import lib.common;


struct VertexOutput {
    float4 position : SV_Position;

    // float4 color;
    float2 uv;
};

[[shader("vertex")]]
VertexOutput vertexMain(Vertex input) {
    VertexOutput output;

    float3 modelPos = input.pos().xyz;
    float3 viewPos = mul3(input.viewMatrix(), modelPos);
    output.position = mul(input.projectionMatrix(), float4(viewPos, 1.0));

    // output.color = input.color();
    output.uv = input.uv();

    if (TAA_Enabled) {
        output.position.xy += scene[0].taa_jitter * (2.0 * output.position.w);
    }

    return output;
}


struct FragmentOutput {
    float4 color_opaque : SV_Target0;
    float4 color_translucent : SV_Target1;
};

[[shader("fragment")]]
FragmentOutput fragmentMain(VertexOutput input) {
    float LOD = albedoTex.CalculateLevelOfDetail(input.uv);

    float4 albedo = albedoTex.SampleLevel(input.uv, LOD);// * input.color;
    // albedo.rgb = RgbToLinear(albedo.rgb);

    FragmentOutput output;
    output.color_opaque = albedo;
    output.color_translucent = albedo;
    return output;
}
