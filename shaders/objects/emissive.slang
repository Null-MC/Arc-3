import aperture;
import buffers.ObjectData;
import lib.common;
import lib.sampling.lmcoord;
import lib.material.pbr;


struct VertexOutput {
    float4 position : SV_Position;

    float4 color;
    float2 light;
    float2 uv;
};

[[shader("vertex")]]
VertexOutput vertexMain(Vertex input) {
    VertexOutput output;

    output.color = input.color();
    output.uv = input.uv();

    output.light = LightMapNorm(input.light());
    output.light = output.light * output.light;

    float3 modelPos = input.pos().xyz;
    float3 viewPos = mul3(input.viewMatrix(), modelPos);
    output.position = mul(input.projectionMatrix(), float4(viewPos, 1.0));

    if (TAA_Enabled) {
        output.position.xy += scene[0].taa_jitter * (2.0 * output.position.w);
    }

    return output;
}


struct FragmentOutput {
    float4 color : SV_Target0;
    uint2 mat_lit : SV_Target1;
};

[[shader("fragment")]]
FragmentOutput fragmentMain(VertexOutput input) {
    float LOD = albedoTex.CalculateLevelOfDetail(input.uv);

    float4 albedo = albedoTex.SampleLevel(input.uv, LOD) * input.color;
    // albedo.rgb = RgbToLinear(albedo.rgb);

    // iris_discardIfNeeded(albedo);
    if (albedo.a < (0.5/255.0)) discard;

    ObjectData_MatLit mat_lit;
    mat_lit.lmcoord = half2(input.light);

    half4 normalData = (half4)normalTex.SampleLevel(input.uv, LOD);
    mat_lit.occlusion = mat_occlusion(normalData.b);

    mat_lit.specular = (half4)specularTex.SampleLevel(input.uv, LOD);

    FragmentOutput output;
    output.color = albedo;
    output.mat_lit = mat_lit.pack();
    return output;
}
