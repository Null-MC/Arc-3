public module voxel_mask;

import aperture;
import lib.common;

extern static const uint VoxelMask_BufferSize = 256;
static const uint3 VoxelMask_BufferCenter = VoxelMask_BufferSize / 2;

static const uint MaskId_Empty = 0;
static const uint MaskId_Water = 1;
static const uint MaskId_Partial = 2;
static const uint MaskId_Solid = 3;


struct VoxelMask {
    uint8_t data;
    // 0-2: Block ID
    // 6-8: Face Mask

    __init(const in uint8_t _data) {
        data = _data;
    }

    [mutating]
    void clear() {
        data = (uint8_t)0;
    }

    uint getId() {
        return bitfieldExtract(data, 0, 2);
    }

    [mutating]
    void setId(const in uint id) {
        data = (uint8_t)bitfieldInsert(data, id, 0, 2);
    }

    uint getFaces() {
        return bitfieldExtract(data, 2, 6);
    }

    [mutating]
    void setFaces(const in uint faces) {
        data = (uint8_t)bitfieldInsert(data, faces, 2, 6);
    }

    // bool testFaces(const in uint faces) {
    //     // return (getFaces() | faces) == 0;
    //     return (getFaces() & faces) != 0;
    //     // return getFaces() != 0;
    // }

    // static uint BuildFaceMask(float3 axisNormal) {
    //     const uint BLOCK_FACE_DOWN = 1;
    //     const uint BLOCK_FACE_UP = 2;
    //     const uint BLOCK_FACE_NORTH = 4;
    //     const uint BLOCK_FACE_SOUTH = 8;
    //     const uint BLOCK_FACE_WEST = 16;
    //     const uint BLOCK_FACE_EAST = 32;

    //     uint mask = 0;
    //     if (axisNormal.y >  EPSILON) mask = BLOCK_FACE_UP;
    //     if (axisNormal.y < -EPSILON) mask = BLOCK_FACE_DOWN;
    //     if (axisNormal.x >  EPSILON) mask = BLOCK_FACE_EAST;
    //     if (axisNormal.x < -EPSILON) mask = BLOCK_FACE_WEST;
    //     if (axisNormal.z >  EPSILON) mask = BLOCK_FACE_SOUTH;
    //     if (axisNormal.z < -EPSILON) mask = BLOCK_FACE_NORTH;
    //     return mask;
    // }

    bool testFace(const in float3 normal) {
        // Builder magic
        int index = int(round(dot(normal, float3(3.0, 6.0, 9.0)))) + 9;
        index = (05370624 >> index) & 7;

        return false;//bitfieldExtract(data, index, 1) != 0;
    }
}

uint VoxelMask_GetBufferIndex(int3 bufferPos) {
	const int3 flatten = int3(1, VoxelMask_BufferSize, VoxelMask_BufferSize*VoxelMask_BufferSize);
	return sumOf(bufferPos * flatten);
}

float3 VoxelMask_GetCenter(const in float3 cameraPos) {
    return VoxelMask_BufferCenter + fract(cameraPos);
}

float3 VoxelMask_GetLocalPosition(const in float3 bufferPos) {
    return bufferPos - VoxelMask_GetCenter(ap.camera.position);
}

float3 VoxelMask_GetBufferPosition(const in float3 localPos) {
    return localPos + VoxelMask_GetCenter(ap.camera.position);
}

bool VoxelMask_InBounds(const in float3 localPos) {
    float3 bufferPos = VoxelMask_GetBufferPosition(localPos);
    return all(clamp(bufferPos, 0.5, VoxelMask_BufferSize-0.5) == bufferPos);
}
