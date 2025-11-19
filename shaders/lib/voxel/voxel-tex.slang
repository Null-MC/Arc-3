public module voxel_tex;

import aperture;
import lib.common;
import lib.voxel.voxel_common;


// float3 VoxelTex_GetCenter(const in float3 cameraPos) {
//     return Voxel_BufferCenter + fract(cameraPos);
// }

// float3 VoxelTex_GetBufferPosition(const in float3 localPos) {
//     return localPos + VoxelTex_GetCenter(ap.camera.position);
// }

// uint VoxelTex_GetBufferIndex(int3 bufferPos) {
// 	const int3 flatten = int3(1, Voxel_Resolution, Voxel_Resolution*Voxel_Resolution);
// 	return sumOf(bufferPos * flatten);
// }

// bool VoxelTex_InBounds(const in int3 bufferPos) {
//     return all(clamp(bufferPos, 0, Voxel_Resolution-1) == bufferPos);
// }

struct VoxelTex {
    uint2 uv_min;
    uint2 uv_size;
    half3 tint;

    uint2 pack(const in float3 normal) {
        uint2 scaled_min = uv_min / 8;
        uint size = uint(ceil(log2(uv_size.x))) - 3;

        uint priority = uint(dot(normal, float3(0.0, 2.0, 1.0) + 2.0));

        uint2 data;
        data.r = bitfieldInsert(     0, scaled_min.x,  0, 12);
        data.r = bitfieldInsert(data.r, scaled_min.y, 12, 12);
        data.r = bitfieldInsert(data.r,         size, 24,  5);
        data.r = bitfieldInsert(data.r,     priority, 29,  3);

        data.g = packUnorm4x8(half4(tint, (half)0.0));
        data.g = bitfieldInsert(data.g, priority, 29, 3);

        return data;
    }

    [mutating]
    void unpack(uint2 data) {
        uint2 scaled_min = uint2(
            bitfieldExtract(data.r,  0, 12),
            bitfieldExtract(data.r, 12, 12));
        
        uint size = bitfieldExtract(data.r, 24, 5);

        uv_min = scaled_min * 8;
        uv_size = uint2(exp2(size + 3));

        tint = unpackUnorm4x8ToHalf(data.g).rgb;
    }
}
