import aperture;
import lib.tags;
import lib.common;
import lib.blocks;
import lib.wind_waving;
import lib.sampling.atlas;
import lib.voxel.voxel_common;
import lib.voxel.voxel_tex;

extern static const int Shadow_CascadeCount;
extern static const bool RENDER_TERRAIN = false;
extern static const bool VOXEL_TEX_ENABLED = true;
extern static const bool ALPHATEST_ENABLED = false;

RWStructuredBuffer<uint2> voxelTexBuffer;


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

    output.blockId = input.blockId().orElse(-1);
    float3 midBlock = input.midBlock().orElse(0.0);

    float3 modelPos = input.pos().xyz;
    float3 shadowViewPos = mul3(input.viewMatrix(), modelPos);
    float3 localPos = mul3(ap.celestial.viewInv, shadowViewPos);

    float3 originPos = localPos + midBlock;
    var block = ap.blocks[output.blockId];

    if (RENDER_TERRAIN && Sky_WindEnabled) {
        uint blockTags = output.blockId >= 0 ? block.tags : 0;
        float3 origin_worldPos = floor(originPos + ap.camera.position);
        localPos += GetWavingOffset(origin_worldPos, midBlock, blockTags, ap.timing.timeElapsed);

        shadowViewPos = mul3(ap.celestial.view, localPos);
    }

    output.position = mul(input.projectionMatrix(), float4(shadowViewPos, 1.0));

    bool voxelize = false;
    // bool isFluidBlock = false;
    if (output.blockId >= 0) {
        voxelize = block.isFullBlock;

		const uint hit_tags = TAG_SLABS | TAG_STAIRS | TAG_LEAVES;
        if (block.hasAnyTag(hit_tags)) voxelize = true;

        if (block.isFluid) {
            color = half4(1.0);
            // isFluidBlock = true;
            voxelize = false;
        }
    }

    static const int voxel_cascade = min(1, Shadow_CascadeCount-1);

    if (VOXEL_TEX_ENABLED && RENDER_TERRAIN && voxelize && input.currentInstance() == voxel_cascade) {
        // float3 origin = modelPos;// mul3(ap.celestial.viewInv, shadowViewPos);
        // if (let value = input.midBlock()) origin += value;
        int3 voxelPos = int3(floor(Voxel_GetBufferPosition(originPos)));

        if (Voxel_InBufferBounds(voxelPos)) {
            float3 normal = input.normal().value;
            float2 midcoord = input.midCoord().value;

            AtlasBounds atlas;
            atlas.Populate(output.uv, midcoord);

            float2 atlasSize;
            albedoTex.GetDimensions(0, atlasSize.x, atlasSize.y);

            VoxelTex voxel;
            voxel.uv_min = uint2(atlas.CoordMin * atlasSize);
            voxel.uv_size = uint2(atlas.CoordSize * atlasSize);
            voxel.tint = color.rgb;

            uint2 voxelData = voxel.pack(normal);
            uint voxelIndex = Voxel_GetBufferIndex(voxelPos);
            InterlockedMax(voxelTexBuffer[voxelIndex].r, voxelData.r);
            InterlockedMax(voxelTexBuffer[voxelIndex].g, voxelData.g);
        }
    }

    output.color = packUnorm4x8(color);

    return output;
}


[[shader("fragment")]]
float4 fragmentMain(VertexOutput input) : SV_Target0 {
    float4 color = float4(0.0, 0.0, 0.0, 1.0);

    if (input.blockId >= 0 && ap.blocks[input.blockId].customId == BLOCK_WATER) {
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
