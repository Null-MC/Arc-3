import aperture;
import lib.common;
import lib.sampling.atlas;
import lib.voxel_tex;

extern static const bool RENDER_TERRAIN = false;
extern static const bool VOXEL_TEX_ENABLED = true;
extern static const bool ALPHATEST_ENABLED = false;
extern static const uint BLOCK_WATER;


struct VertexOutput {
    float4 position : SV_Position;

    float2 uv;
    nointerpolation uint color;
    nointerpolation int blockId;
};

[[shader("vertex")]]
VertexOutput vertexMain(Vertex input) {
    VertexOutput output;
    
    half4 color = half4(input.color());
    output.uv = input.uv();

    output.blockId = -1;
    if (let value = input.blockId()) output.blockId = value;

    float3 modelPos = input.pos().xyz;
    float3 shadowViewPos = mul3(input.viewMatrix(), modelPos);
    output.position = mul(input.projectionMatrix(), float4(shadowViewPos, 1.0));

    bool isFullBlock = false;
    bool isFluidBlock = false;
    if (output.blockId >= 0) {
        isFullBlock = ap.blocks[output.blockId].isFullBlock;

        if (ap.blocks[output.blockId].isFluid) {
            color = half4(1.0);
            isFluidBlock = true;
        }
    }

    if (VOXEL_TEX_ENABLED && RENDER_TERRAIN && isFullBlock && !isFluidBlock && input.currentInstance() == 1) {
        float3 origin = modelPos;// mul3(ap.celestial.viewInv, shadowViewPos);
        if (let value = input.midBlock()) origin += value;
        int3 voxelPos = int3(floor(VoxelTex_GetBufferPosition(origin)));

        if (VoxelTex_InBounds(voxelPos)) {
            float3 normal = input.normal().value;
            float2 midcoord = input.midCoord().value;

            AtlasBounds atlas;
            atlas.Populate(output.uv, midcoord);

            float2 atlasSize;
            albedoTex.GetDimensions(0, atlasSize.x, atlasSize.y);

            uint2 uv_min = uint2(atlas.CoordMin * atlasSize);
            uint2 uv_size = uint2(atlas.CoordSize * atlasSize);
            uint data = VoxelTex_pack(uv_min, uv_size, normal);
            InterlockedMax(imgVoxelTexId[voxelPos], data);
        }
    }

    output.color = packUnorm4x8(color);

    return output;
}


[[shader("fragment")]]
float4 fragmentMain(VertexOutput input, int layer : SV_RenderTargetArrayIndex) : SV_Target0 {
    float4 color = float4(0.0, 0.0, 0.0, 1.0);

    if (input.blockId >= 0 && ap.blocks[input.blockId].customId == BLOCK_WATER) {
        color = float4(1.0, 1.0, 1.0, 0.02);
    }
    else if (ALPHATEST_ENABLED && layer <= 2) {
        half4 tint = unpackUnorm4x8ToHalf(input.color);
        color = albedoTex.Sample(input.uv) * tint;
        iris_discardIfNeeded(color);

        color.rgb = RgbToLinear(color.rgb);
        color.rgb = lerp(color.rgb, 0.0, pow2(color.a));
        color.rgb = LinearToRgb(color.rgb);
    }

    return color;
}
