import aperture;
import lib.common;
import lib.light.floodfill_sky;
import lib.voxel.voxel_common;


groupshared int group_maxY;
groupshared half group_light[10*6*10];

static const int3 flattenShared = int3(1, 10, 60);

int getSharedCoord(int3 pos) {
	return sumOf(pos * flattenShared);
}

int3 GetVoxelFrameOffset() {
    float3 posNow = FloodFill_Sky_GetBufferCenter(ap.camera.position);
    float3 posPrev = FloodFill_Sky_GetBufferCenter(ap.temporal.position);

    float3 posLast = fract(posNow) + (ap.temporal.position - posPrev) - (ap.camera.position - posNow);
    return int3(floor(posLast));
}

half sampleShared(int3 pos) {
	int shared_index = getSharedCoord(pos);
	return group_light[shared_index];
}

half maxOfNeighbors(const in int3 bufferPos) {
	half nX1 = sampleShared(bufferPos + int3(-1,  0,  0));
	half nX2 = sampleShared(bufferPos + int3( 1,  0,  0));
	half nY1 = sampleShared(bufferPos + int3( 0, -1,  0));
	half nY2 = sampleShared(bufferPos + int3( 0,  1,  0));
	half nZ1 = sampleShared(bufferPos + int3( 0,  0, -1));
	half nZ2 = sampleShared(bufferPos + int3( 0,  0,  1));

	const float avgFalloff = 0.98 / 6.0;
	return (nX1 + nX2 + nY1 + nY2 + nZ1 + nZ2) * avgFalloff;
	// return max(max(max(max(nX1, nX2), max(nY1, nY2)), max(nZ1, nZ2)) - 1.0, 0.0);
}


struct ComputeInput {
    uint groupIndex : SV_GroupIndex;
    uint3 groupPos : SV_GroupID;
    uint3 localPos : SV_GroupThreadID;
    uint3 globalPos : SV_DispatchThreadID;
};

[[shader("compute")]]
[numthreads(8, 4, 8)]
void floodfill_sky_spread(ComputeInput input) {
	int3 workGroupOffset = int3(input.groupPos * WorkgroupSize()) - 1;
	int3 voxelFrameOffset = GetVoxelFrameOffset();
	uint x_offset = input.groupIndex * 3;

	// populate shared neighbors
	[ForceUnroll]
	for (int i = 0; i < 3; i++) {
		int x = x_offset + i;
		if (x >= 10*6*10) break;
	
		int3 bufferPos = workGroupOffset + int3(x / flattenShared) % int3(10, 6, 10);
		int3 texcoordPrev = bufferPos - voxelFrameOffset;

		half samplePrev = 0;
		if (FloodFill_Sky_InBounds(texcoordPrev))
			samplePrev = texFloodFill_Sky_read[texcoordPrev];

		group_light[x] = samplePrev;
	}

	GroupMemoryBarrierWithGroupSync();

	// propagate light from neighbors
	float3 localPos = FloodFill_Sky_GetLocalPosition(input.globalPos + 0.5);
	int blockId = ap.voxel[int3(floor(localPos + ap.camera.position))].blockId;
	bool isFullBlock = blockId > 0 && ap.blocks[blockId].isFullBlock;

	float lit = 0.0;
	if (!isFullBlock) {
		lit = maxOfNeighbors(input.localPos + 1);
	}

	imgFloodFill_Sky_write[input.globalPos] = (half)lit;
}

[[shader("compute")]]
[numthreads(1, 256, 1)]
void floodfill_sky(ComputeInput input) {
	if (input.groupIndex == 0) {
		group_maxY = int.minValue;
	}

	GroupMemoryBarrierWithGroupSync();

	if (any(input.globalPos >= FloodFill_Sky_BufferSize)) return;

	float3 localPos = FloodFill_Sky_GetLocalPosition(input.globalPos + 0.5);
	int3 voxelPos = int3(floor(localPos + ap.camera.position));

	if (ap.voxel[voxelPos].blockId > 0) {
		InterlockedMax(group_maxY, voxelPos.y);
	}

	GroupMemoryBarrierWithGroupSync();

	if (voxelPos.y > group_maxY)
		imgFloodFill_Sky_write[input.globalPos] = 16;
}
