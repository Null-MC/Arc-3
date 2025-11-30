import aperture;
import buffers.ObjectData;
import lib.common;
import lib.blocks;
import lib.octohedral;
import lib.sampling.atlas;
import lib.sampling.lmcoord;
import lib.sampling.linear;
import lib.sampling.dfd_normal;
import lib.material.pbr;
import lib.material.parallax;
import lib.water.waves;
import lib.light.fresnel;
import lib.tbn;

extern static const int RefractMode;
extern static const bool Material_SmoothNormals;
extern static const bool Water_WaveEnabled = false;
extern static const bool RENDER_TERRAIN = false;
extern static const bool RENDER_PARTICLES = false;
extern static const bool RENDER_HAND = false;

static const bool SupportsParallax = Parallax_Enabled && !RENDER_PARTICLES;
static const bool SupportsTexNormals = !RENDER_PARTICLES;

Sampler2D<float> solidDepthTex;


struct VertexOutput {
    float4 position : SV_Position;

    float2 uv;
    float2 light;
    float3 localPos;
    float occlusion;
    float3 tangentViewPos;
    
    nointerpolation int blockId;
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

    // if (SupportsParallax) {
        output.localPos = mul3(ap.camera.viewInv, viewPos);
    // }

    output.uv = input.uv();
    half4 color = half4(input.color());
    output.occlusion = input.ao();

    output.light = LightMapNorm(input.light());
    output.light = output.light * output.light;

    output.blockId = input.blockId().orElse(-1);

    if (let value = input.overlayColor()) {
        half4 overlay = half4(value);
        color.rgb = lerp(color.rgb, overlay.rgb, overlay.a);
    }

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
    half3 tint : SV_Target1;
    uint2 normals : SV_Target2;
    uint2 mat_lit : SV_Target3;
    // half2 velocity : SV_Target4;
};

[[shader("fragment")]]
FragmentOutput fragmentMain(VertexOutput input, float2 fragPos : SV_Position) {
    float2 tex_uv = input.uv;
    float LOD = albedoTex.CalculateLevelOfDetail(tex_uv);

    AtlasBounds atlas;
    float3 tanViewDir;
    float texDepth = 1.0;
    float3 traceCoordDepth = 1.0;
    bool skipParallax = false;

    float viewDist = length(input.localPos);

    if (SupportsParallax) {
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

    // mat_lit.blockMapId = input.blockId;
    mat_lit.blockMapId = 0;

    half4 tint = unpackUnorm4x8ToHalf(input.color);
    half4 color = (half4)albedoTex.SampleLevel(tex_uv, LOD) * tint;
    half4 normalData = (half4)normalTex.SampleLevel(tex_uv, LOD);
    mat_lit.specular = (half4)specularTex.SampleLevel(tex_uv, LOD);

    iris_discardIfNeeded(color);

    if (RENDER_PARTICLES) {
        if (color.a < (0.5/255.0)) discard;
    }

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
        half smoothF = saturate(minOf(half2(smoothXY*localSize - 1.0)));

        half2 smooth_normal = half2(normalTex.SampleLevelLinearRGB(uv, LOD, f).rg);
        normalData.rg = lerp(normalData.rg, smooth_normal, smoothF);
    }

    normals.geo = OctDecode(unpackUnorm2x16ToHalf(input.normal));
    normals.tex = normals.geo;

    mat_lit.lmcoord = half2(input.light);

    bool isWater = false;
    if (RENDER_TERRAIN) {
        mat_lit.blockMapId = ap.blocks[input.blockId].customId;
        isWater = mat_lit.blockMapId == BLOCK_WATER;

        if (isWater) {
            color = half4(0, 0, 0, (half)0.02);
            // color = half4(1,0,0,1);
            mat_lit.specular.r = (half)0.96;
            mat_lit.specular.g = (half)0.02;
        }
    }

    if (RENDER_HAND) mat_lit.blockMapId = BLOCK_HAND;

    if (SupportsTexNormals) {
        if (Water_WaveEnabled && isWater) {
            if (abs(normals.geo.y) > EPSILON) {
                float3 offsetLocalPos = input.localPos;
                // offsetLocalPos.y -= input.waveOffset;

                int octaves = GetWaveOctaveCount(viewDist);
                float3 waveOffset = GetWaveHeight(ap.camera.position + offsetLocalPos, input.light.y, ap.timing.timeElapsed, octaves);

                normals.tex = half3(getSurfaceNormal((waveOffset + offsetLocalPos), float3(0,1,0)));
            }
        }
        else if (MATERIAL_FORMAT != MAT_NONE) {
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
    }

    half tex_occlusion = mat_occlusion(normalData.b);
    mat_lit.occlusion = (half)input.occlusion * tex_occlusion;

    FragmentOutput output;
    output.tint = half3(1);

    if (!isWater) {
        half3 albedo = RgbToLinear(color.rgb);
        output.tint = lerp(half3(1.0), albedo, color.a);
        output.tint = LinearToRgb(output.tint);
    }

    // TODO: apply fresnel to opacity?
    float3 viewLocalDir = -normalize(input.localPos);
    half f0_metal = mat_f0_metal(mat_lit.specular.g);
    half NoVm = max((half)dot(normals.tex, viewLocalDir), (half)0.0);
    half F_NoV = F_Lazanyi2019(NoVm, f0_metal);
    color.a = 1.0 - ((1.0 - color.a) * (1.0 - F_NoV));

    output.albedo = color;
    output.normals = normals.pack();
    output.mat_lit = mat_lit.pack();
    // output.velocity = half2(0.0);

    return output;
}
