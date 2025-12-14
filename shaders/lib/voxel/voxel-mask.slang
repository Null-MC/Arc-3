public module voxel_mask;

import aperture;
import lib.common;
import lib.voxel.voxel_common;

static const uint MaskId_Empty = 0;
static const uint MaskId_Solid = 1;
static const uint MaskId_Water = 2;
static const uint MaskId_Tint = 3;

// static const uint MaskFace_Down = 0;
// static const uint MaskFace_Up = 1;
// static const uint MaskFace_North = 2;
// static const uint MaskFace_South = 3;
// static const uint MaskFace_West = 4;
// static const uint MaskFace_East = 5;


struct VoxelMask {
    uint data;
    // 0-1: Block ID
    // 2-7: Face Mask
    // 8-31: rgb tint

    __init(const in uint _data) {
        data = _data;
    }

    [mutating]
    void clear() {
        data = 0;
    }

    uint getId() {
        return bitfieldExtract(data, 0, 2);
    }

    [mutating]
    void setId(const in uint id) {
        data = bitfieldInsert(data, id, 0, 2);
    }

    uint getFaces() {
        return bitfieldExtract(data, 2, 6);
    }

    [mutating]
    void setFaces(const in uint faces) {
        data = bitfieldInsert(data, faces, 2, 6);
    }

    bool testFace(const in float3 normal) {
        // Builder magic
        int index = int(round(dot(normal, float3(3.0, 6.0, 9.0)))) + 9;
        index = (03150402 >> index) & 7;

        return bitfieldExtract(data, 2 + index, 1) != 0;
    }

    half3 getTint() {
        return unpackUnorm4x8ToHalf(bitfieldExtract(data, 8, 24)).rgb;
    }

    [mutating]
    void setTint(const in half3 tint) {
        uint tint_data = packUnorm4x8(half4(tint, 1));
        data = bitfieldInsert(data, tint_data, 8, 24);
    }

    static VoxelMask EMPTY = new VoxelMask(0);
}
