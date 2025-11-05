import aperture;
import lib.common;
import lib.material.pbr;
import lib.sky.sample_final;

extern static const float BLOCK_LUX;
extern static const bool Debug_WhiteWorld;
extern static const bool World_HasSky;

Sampler2D<float> solidDepthTex;

Sampler2D<half4> texAlbedoGB;
// Sampler2D<float3> texPositionGB;
Sampler2D<uint2> texNormalGB;
Sampler2D<uint2> texMatLightGB;
Sampler2D<half3> texDiffuse;
Sampler2D<half3> texSpecular;


[[shader("fragment")]]
half4 lightingFinal(float2 pos : SV_Position) : SV_Target0 {
    uint2 uv = uint2(pos);
    float depth = solidDepthTex[uv];

    half3 final = half3(0.0);
    if (depth < 1.0) {
        // uint2 normals = texNormalGB[uv];
        // float3 geo_normal = normalize(unpackUnorm4x8ToFloat(normals.r).xyz * 2.0 - 1.0);
        // float3 tex_normal = normalize(unpackUnorm4x8ToFloat(normals.g).xyz * 2.0 - 1.0);

        uint2 matLightData = texMatLightGB[uv];
        half4 specularData = unpackUnorm4x8ToHalf(matLightData.r);
        half4 lightData = unpackUnorm4x8ToHalf(matLightData.g);

        float occlusion = lightData.b;

        half4 color = texAlbedoGB[uv];
        half3 diffuse = texDiffuse[uv];
        half3 specular = texSpecular[uv];
        float emission = mat_emission(specularData) * BLOCK_LUX;

        half3 albedo = RgbToLinear(color.rgb);
        if (Debug_WhiteWorld) albedo = half3(0.85);

        half3 ambient = half3(0.2 * occlusion);
        final = albedo.rgb * (diffuse + half3(emission) + ambient) + specular;
    }
    else if (World_HasSky) {
        float2 texcoord = pos / ap.game.screenSize;
        if (TAA_Enabled) texcoord += scene[0].taa_jitter;

        float3 clipPos = float3(texcoord, depth) * 2.0 - 1.0;
        float3 viewPos = project(ap.camera.projectionInv, clipPos);
        float3 localPos = mul3(ap.camera.viewInv, viewPos);
        float3 viewLocalDir = normalize(localPos);

        final = sampleSkyFinal(localPos, viewLocalDir, false);
    }

    return half4(final, half2(1.0).x);
}
