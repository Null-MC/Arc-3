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
	var ap_voxel = ap.voxel[int3(floor(worldPos))];

	VoxelMask voxel_mask = VoxelMask.EMPTY;

	if (ap_voxel.blockId >= 0) {
		var block = ap_voxel.block;

		static const uint partial_tags = TAG_SLABS | TAG_STAIRS | TAG_LEAVES;

		uint maskId = MaskId_Empty;
		half3 tint = half3(1.0);

		if (block.isFluid) maskId = MaskId_Water;
		else if (block.isFullBlock) maskId = MaskId_Solid;
		else if (block.hasAnyTag(partial_tags)) {
			maskId = MaskId_Tint;
			tint = half3(0.5);
		}
		else if (block.hasAnyTag(TAG_TINTS_LIGHT)) {
			maskId = MaskId_Tint;
			tint = half3(block.lightColor.rgb);
		}

		voxel_mask.setId(maskId);
		voxel_mask.setTint(tint);
		voxel_mask.setFaces(bitfieldExtract(block.metadata, 0, 6));
	}

	int index = Voxel_GetBufferIndex(input.globalPos);
	VoxelMaskBuffer[index] = voxel_mask;
}
