import aperture;
import buffers.ObjectData;
import lib.common;
import lib.blocks;
import lib.octohedral;
import lib.sampling.atlas;
import lib.sampling.lmcoord;
import lib.sampling.linear;
import lib.material.pbr;
import lib.material.parallax;
import lib.wind_waving;
import lib.tbn;

extern static const bool Material_SmoothNormals;
extern static const bool RENDER_ENTITY = false;
extern static const bool RENDER_TERRAIN = false;
extern static const bool RENDER_PARTICLES = false;
extern static const bool RENDER_TEXT = false;
extern static const bool RENDER_HAND = false;

static const bool SupportsParallax = Parallax_Enabled && !(RENDER_PARTICLES || RENDER_TEXT);
static const bool SupportsTexNormals = !RENDER_PARTICLES;


struct VertexOutput {
    float4 position : SV_Position;

    float2 uv;
    float2 light;
    float3 localPos;
    float occlusion;
    float3 tangentViewPos;
    float2 velocity;
    
    nointerpolation int blockId;
    nointerpolation uint color;
    nointerpolation uint color_overlay;
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
    output.localPos = mul3(ap.camera.viewInv, viewPos);
    
    float3 velocity_local = 0.0;
    if (RENDER_TERRAIN && Sky_WindEnabled) {
        int blockId = input.blockId().orElse(-1);
        float3 midPos = input.midBlock().orElse(0.0);

        float3 originPos = output.localPos + midPos;
        uint blockTags = blockId >= 0 ? ap.blocks[blockId].tags : 0;
        float3 origin_worldPos = floor(originPos + ap.camera.position);
        float3 waving_offset = GetWavingOffset(origin_worldPos, midPos, blockTags, ap.timing.timeElapsed);

        output.localPos += waving_offset;
        viewPos = mul3(ap.camera.view, output.localPos);

        if (TAA_Enabled) {
            float elapsed_last = ap.timing.timeElapsed - ap.timing.lastFrameTime;
            float3 waving_offset_last = GetWavingOffset(origin_worldPos, midPos, blockTags, elapsed_last);
            velocity_local = waving_offset - waving_offset_last;
        }
    }

    output.uv = input.uv();
    output.occlusion = input.ao();
    output.occlusion = pow2(output.occlusion);

    output.light = LightMapNorm(input.light());
    output.light = output.light * output.light;

    output.blockId = input.blockId().orElse(-1);

    half4 color = half4(input.color());
    output.color = packUnorm4x8(color);

    // if (let value = input.overlayColor()) {
    //     half4 overlay = half4(value);
    //     color.rgb = lerp(color.rgb, overlay.rgb, overlay.a);
    // }

    half4 overlayColor = half4(input.overlayColor().orElse(half4(1, 1, 1, 0)));
    output.color_overlay = packUnorm4x8(overlayColor);

    float3 viewNormal;
    output.normal = 0u;
    if (let value = input.normal()) {
        viewNormal = mul(input.normalMatrix(), value);
        float3 localNormal = mul(float3x3(ap.camera.viewInv), viewNormal);
        localNormal = normalize(localNormal);

        output.normal = packUnorm2x16(OctEncode(half3(localNormal)));
    }

    float4 viewTangent;
    output.tangent = 0u;
    if (SupportsTexNormals && MATERIAL_FORMAT != MAT_NONE) {
        if (let value = input.tangent()) {
            viewTangent.xyz = mul(input.normalMatrix(), value.xyz);
            float3 localTangent = mul(float3x3(ap.camera.viewInv), viewTangent.xyz);
            localTangent = normalize(localTangent);
            viewTangent.w = value.w;

            output.tangent = packUnorm4x8(half4(
                OctEncode(half3(localTangent)),
                (half)0.0,
                step((half)0.0, (half)value.w)));
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
        // float3 viewPos = mul3(ap.camera.view, output.localPos);
        output.tangentViewPos = mul(TBN, viewPos.xyz);
    }

    output.position = mul(input.projectionMatrix(), float4(viewPos, 1.0));

    if (TAA_Enabled) {
        float3 lastPos = output.localPos - velocity_local;
        float3 lastViewPos = mul3(ap.camera.view, lastPos);
        float3 lastNdcPos = project(ap.camera.projection, lastViewPos);
        output.velocity = output.position.xy / output.position.w - lastNdcPos.xy;

        // if (RENDER_HAND) ndcPos.z /= MC_HAND_DEPTH;

        output.position.xy += scene[0].taa_jitter * (2.0 * output.position.w);
    }

    return output;
}


struct FragmentOutput {
    half4 albedo : SV_Target0;
    uint2 normals : SV_Target1;
    uint2 mat_lit : SV_Target2;
    half2 velocity : SV_Target3;
};

[[shader("fragment")]]
FragmentOutput fragmentMain(VertexOutput input) {
    float2 tex_uv = input.uv;
    float LOD = albedoTex.CalculateLevelOfDetail(tex_uv);
    LOD = max(LOD - 1.0, 0.0);

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

            float2 localCoord = atlas.GetLocalCoord(tex_uv);
            tex_uv = GetParallaxCoord(localCoord, int(LOD), atlas, tanViewDir, viewDist, texDepth, traceCoordDepth);
        }
    }

    ObjectData_Normals normals;
    ObjectData_MatLit mat_lit;

    half4 tint = unpackUnorm4x8ToHalf(input.color);
    half4 albedo = (half4)albedoTex.SampleLevel(tex_uv, LOD) * tint;
    half4 normalData = (half4)normalTex.SampleLevel(tex_uv, LOD);
    mat_lit.specular = (half4)specularTex.SampleLevel(tex_uv, LOD);

    iris_discardIfNeeded(albedo);

    if (RENDER_ENTITY) {
        half4 overlayColor = unpackUnorm4x8ToHalf(input.color_overlay);
        albedo.rgb = lerp(overlayColor.rgb, albedo.rgb, overlayColor.a);
    }

    if (RENDER_TERRAIN) {
        mat_lit.blockMapId = ap.blocks[input.blockId].customId;
    }

    if (RENDER_HAND) mat_lit.blockMapId = BLOCK_HAND;

    if (Material_SmoothNormals) {
        float2 atlasSize;
        normalTex.GetDimensions(0, atlasSize.x, atlasSize.y);

        AtlasBounds atlas;
        atlas.CoordMin = unpackHalf2x16ToFloat(input.atlasCoordMin);
        atlas.CoordSize = unpackHalf2x16ToFloat(input.atlasCoordSize);

        float2 uv[4];
        float2 localCoord = atlas.GetLocalCoord(input.uv);
        float2 atlasTileSize = atlas.CoordSize * atlasSize;
        float2 f = GetLinearCoords(localCoord, atlasTileSize, uv);

        uv[0] = atlas.GetAtlasCoord(uv[0]);
        uv[1] = atlas.GetAtlasCoord(uv[1]);
        uv[2] = atlas.GetAtlasCoord(uv[2]);
        uv[3] = atlas.GetAtlasCoord(uv[3]);

        half2 smoothXY = half2(0.5) - half2(abs(localCoord - 0.5));
        float2 localSize = atlasSize * atlas.CoordSize;
        half smoothF = saturate(minOf(smoothXY*localSize - 1.0));

        half2 smooth_normal = half2(normalTex.SampleLevelLinearRGB(uv, LOD, f).rg);
        normalData.rg = lerp(normalData.rg, smooth_normal, smoothF);
    }

    normals.geo = OctDecode(unpackUnorm2x16ToHalf(input.normal));
    normals.tex = normals.geo;

    mat_lit.lmcoord = half2(input.light);

    if (SupportsTexNormals && MATERIAL_FORMAT != MAT_NONE) {
        normals.tex = mat_normal(normalData.rgb);

        if (SupportsParallax && !skipParallax && Parallax_Type == POM_TYPE_SHARP) {
            float depthDiff = max(texDepth - traceCoordDepth.z, 0.0);

            if (depthDiff >= ParallaxSharpThreshold) {
                normals.tex = (half3)GetParallaxSlopeNormal(tex_uv, int(LOD), atlas, traceCoordDepth.z, tanViewDir);
            }
        }

        half4 tangentData = unpackUnorm4x8ToHalf(input.tangent);
        float3x3 TBN = GetTBN(normals.geo, OctDecode(tangentData.xy), tangentData.w);

        normals.tex = normalize(half3(mul(normals.tex, TBN)));
    }

    half tex_occlusion = mat_occlusion(normalData.b);
    mat_lit.occlusion = (half)input.occlusion * tex_occlusion;

    FragmentOutput output;
    output.albedo = albedo;
    output.normals = normals.pack();
    output.mat_lit = mat_lit.pack();
    output.velocity = half2(TAA_Enabled ? input.velocity : 0.0);
    return output;
}
