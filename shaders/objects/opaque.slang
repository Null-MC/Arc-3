import aperture;
import buffers.OpaqueObject;
import lib.common;
import lib.sampling.atlas;
import lib.sampling.lmcoord;
import lib.material.pbr;
import lib.material.parallax;
import lib.tbn;

extern static const bool RENDER_TERRAIN = false;
extern static const bool RENDER_PARTICLES = false;

static const bool SupportsParallax = Parallax_Enabled && !RENDER_PARTICLES;
static const bool SupportsTexNormals = !RENDER_PARTICLES;


struct VertexOutput {
    float4 position : SV_Position;

    float2 uv;
    float2 light;
    float3 localPos;
    float occlusion;
    float3 tangentViewPos;
    
    nointerpolation uint color;
    nointerpolation uint normal;
    nointerpolation uint tangent;
    nointerpolation uint atlasCoordMin;
    nointerpolation uint atlasCoordSize;
};

[[shader("vertex")]]
VertexOutput vertexMain(Vertex input) {
    VertexOutput output;

    float3 modelPos = input.pos().xyz;
    float3 viewPos = mul3(input.viewMatrix(), modelPos);
    output.position = mul(input.projectionMatrix(), float4(viewPos, 1.0));

    if (SupportsParallax) {
        output.localPos = mul3(ap.camera.viewInv, viewPos);
    }

    output.uv = input.uv();
    half4 color = half4(input.color());
    output.occlusion = input.ao();

    output.light = LightMapNorm(input.light());
    output.light = output.light * output.light;

    if (let value = input.overlayColor()) {
        half4 overlay = half4(value);
        color.rgb = lerp(color.rgb, overlay.rgb, overlay.a);
    }

    float3 viewNormal;
    output.normal = 0u;
    if (let value = input.normal()) {
        viewNormal = mul(input.normalMatrix(), value);
        float3 localNormal = mul(float3x3(ap.camera.viewInv), viewNormal);
        output.normal = packUnorm4x8(float4(normalize(localNormal) * 0.5 + 0.5, 1.0));
    }

    float4 viewTangent;
    if (SupportsTexNormals && MATERIAL_FORMAT != MAT_NONE) {
        if (let value = input.tangent()) {
            viewTangent.xyz = mul(input.normalMatrix(), value.xyz);
            float3 tangent = normalize(mul(float3x3(ap.camera.viewInv), viewTangent.xyz));
            output.tangent = packUnorm4x8(float4(tangent * 0.5 + 0.5, step(0.0, value.w)));
            viewTangent.w = value.w;
        }
    }

    if (SupportsParallax) {
        if (let midCoord = input.midCoord()) {
            AtlasBounds atlas;
            atlas.Populate(output.uv, midCoord);
            output.atlasCoordMin = packHalf2x16(atlas.CoordMin);
            output.atlasCoordSize = packHalf2x16(atlas.CoordSize);
        }

        float3x3 TBN = GetTBN(viewNormal, viewTangent.xyz, viewTangent.w);
        float3 viewPos = mul3(ap.camera.view, output.localPos);
        output.tangentViewPos = mul(TBN, viewPos.xyz);
    }

    if (TAA_Enabled) {
        output.position.xy += scene[0].taa_jitter * (2.0 * output.position.w);
    }

    output.color = packUnorm4x8(color);

    return output;
}


struct FragmentOutput {
    half4 albedo : SV_Target0;
    // float3 position : SV_Target1;
    uint2 normals : SV_Target1;
    uint2 mat_lit : SV_Target2;
    half2 velocity : SV_Target3;
};

[[shader("fragment")]]
FragmentOutput fragmentMain(VertexOutput input) {
    float2 uv = input.uv;
    float LOD = albedoTex.CalculateLevelOfDetail(uv);

    AtlasBounds atlas;
    float3 tanViewDir;
    float texDepth = 1.0;
    float3 traceCoordDepth = 1.0;
    bool skipParallax = false;

    if (SupportsParallax) {
        float viewDist = length(input.localPos);
        tanViewDir = normalize(input.tangentViewPos);

        if (!skipParallax && viewDist < MATERIAL_PARALLAX_MAXDIST) {
            atlas.CoordMin = unpackHalf2x16ToFloat(input.atlasCoordMin);
            atlas.CoordSize = unpackHalf2x16ToFloat(input.atlasCoordSize);

            float2 localCoord = atlas.GetLocalCoord(uv);
            uv = GetParallaxCoord(localCoord, int(LOD), atlas, tanViewDir, viewDist, texDepth, traceCoordDepth);
        }
    }

    OpaqueObject_Normals normals;
    OpaqueObject_MatLit mat_lit;

    half4 tint = unpackUnorm4x8ToHalf(input.color);
    half4 color = albedoTex.SampleLevel(uv, LOD) * tint;
    half4 normalData = normalTex.SampleLevel(uv, LOD);
    mat_lit.specular = specularTex.SampleLevel(uv, LOD);

    iris_discardIfNeeded(color);

    normals.geo = unpackUnorm4x8ToHalf(input.normal).xyz;
    normals.geo = normalize(normals.geo * 2.0 - 1.0);
    normals.tex = normals.geo;

    mat_lit.lmcoord = half2(input.light);

    if (SupportsTexNormals && MATERIAL_FORMAT != MAT_NONE) {
        normals.tex = mat_normal(normalData.rgb);

        if (SupportsParallax && !skipParallax && Parallax_Type == POM_TYPE_SHARP) {
            float depthDiff = max(texDepth - traceCoordDepth.z, 0.0);

            if (depthDiff >= ParallaxSharpThreshold) {
                normals.tex = GetParallaxSlopeNormal(uv, int(LOD), atlas, traceCoordDepth.z, tanViewDir);
            }
        }

        half4 tangent = unpackUnorm4x8ToHalf(input.tangent) * 2.0 - 1.0;
        float3x3 TBN = GetTBN(normals.geo, normalize(tangent.xyz), tangent.w);

        normals.tex = normalize(mul(normals.tex, TBN));
    }

    float tex_occlusion = mat_occlusion(normalData.b);
    mat_lit.occlusion = input.occlusion * tex_occlusion;

    FragmentOutput output;
    output.albedo = color;
    output.normals = normals.pack();
    output.mat_lit = mat_lit.pack();
    output.velocity = half2(0.0);
    return output;
}
