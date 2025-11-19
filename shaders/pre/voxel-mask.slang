import aperture;
import lib.common;
import lib.blocks;
import lib.tags;
import lib.voxel.voxel_common;
import lib.voxel.voxel_mask;


RWStructuredBuffer<VoxelMask> VoxelMaskBuffer;


struct ComputeInput {
    uint groupIndex : SV_GroupIndex;
    uint3 groupPos : SV_GroupID;
    uint3 localPos : SV_GroupThreadID;
    uint3 globalPos : SV_DispatchThreadID;
};

[[shader("compute")]]
[numthreads(8, 8, 8)]
void buildVoxelMask(ComputeInput input) {
	if (any(input.globalPos >= Voxel_Resolution)) return;

	float3 worldPos = Voxel_GetLocalPosition(input.globalPos + 0.5) + ap.camera.position;
	var voxel = ap.voxel[int3(floor(worldPos))];

	uint maskId = 0;
	uint maskFaces = 0;

	if (voxel.blockId >= 0) {
		var block = voxel.block;

		if (block.customId == BLOCK_WATER) maskId = MaskId_Water;
		else if (block.isFullBlock) maskId = MaskId_Solid;

		const uint hit_tags = TAG_SLABS | TAG_STAIRS | TAG_LEAVES;
		if (block.hasAnyTag(hit_tags)) maskId = MaskId_Partial;

		maskFaces = bitfieldExtract(block.metadata, 0, 6);
	}

	int index = Voxel_GetBufferIndex(input.globalPos);

	VoxelMaskBuffer[index].setId(maskId);
	VoxelMaskBuffer[index].setFaces(maskFaces);
}
