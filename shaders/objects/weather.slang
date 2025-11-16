import aperture;
import lib.common;
import lib.sky.common;
import lib.sky.sample_transmit;
import lib.sky.sample_irradiance;
import lib.shadow;
import lib.material.pbr;


struct VertexOutput {
    float4 position : SV_Position;

    float4 color;
    float2 light;
    float2 uv;
    float3 localPos;
};

[[shader("vertex")]]
VertexOutput vertexMain(Vertex input) {
    VertexOutput output;

    float3 modelPos = input.pos().xyz;
    float3 viewPos = mul3(input.viewMatrix(), modelPos);
    output.position = mul(input.projectionMatrix(), float4(viewPos, 1.0));
    output.localPos = mul3(ap.camera.viewInv, viewPos);

    output.color = input.color();
    output.light = input.light();
    output.uv = input.uv();

    output.uv += scene[0].WeatherOffset;

    if (TAA_Enabled) {
        output.position.xy += scene[0].taa_jitter * (2.0 * output.position.w);
    }

    return output;
}


struct FragmentOutput {
    float4 color : SV_Target0;
    //float2 velocity : SV_Target2;
};

[[shader("fragment")]]
FragmentOutput fragmentMain(VertexOutput input) {
    float LOD = albedoTex.CalculateLevelOfDetail(input.uv);

    float4 albedo = albedoTex.SampleLevel(input.uv, LOD) * input.color;
    iris_discardIfNeeded(albedo);

    albedo.rgb = RgbToLinear(albedo.rgb);
    if (Debug_WhiteWorld) albedo.rgb = WhiteWorldColor;

    float4 normalData = normalTex.SampleLevel(input.uv, LOD);

    float lmcoord_y = input.light.g*input.light.g;

    float viewDist = length(input.localPos);
    float offset_bias = viewDist * 0.002;

    float3 shadowViewPos = mul3(ap.celestial.view, input.localPos);
    shadowViewPos.z += offset_bias;

    const float paddingBlocks = 0.05;
    int shadowCascade = GetShadowProjection(shadowViewPos, paddingBlocks);

    float shadow = 1.0;
    if (shadowCascade >= 0) {
        float3 shadowPos = mul3(ap.celestial.projection[shadowCascade], shadowViewPos).xyz * 0.5 + 0.5;
        shadow = SampleShadow(shadowPos, shadowCascade);
    }

    float3 skyPos = getSkyPosition(input.localPos);

    const float NoLm_sun = 1.0;
    float3 sunTransmit = sampleSkyTransmit(skyPos, scene[0].SunLocalDir);
    float3 lightSun = NoLm_sun * sunTransmit * scene[0].SunColor;

    const float NoLm_moon = 1.0;
    float3 moonTransmit = sampleSkyTransmit(skyPos, scene[0].MoonLocalDir);
    float3 lightMoon = NoLm_moon * moonTransmit * scene[0].MoonColor;

    float3 ambient_normal = float3(0.0, 1.0, 0.0);
    float3 ambient = sampleSkyIrradiance(ambient_normal) * lmcoord_y;

    float3 diffuse = (lightSun + lightMoon) / PI * shadow + ambient;
    float3 specular = 0.0;

    float4 color = albedo;
    color.rgb = color.rgb * diffuse + specular;

    color.rgb *= color.a;

    FragmentOutput output;
    output.color = color;
    //output.velocity = 0.0;
    return output;
}
