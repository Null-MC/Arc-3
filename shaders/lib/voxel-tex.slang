import aperture;
import lib.common;

extern static const int VoxelTex_BufferSize = 256;

static const uint3 VoxelTex_BufferCenter = VoxelTex_BufferSize / 2;

[[vk::image_format("r32ui")]]
RWTexture3D<uint> imgVoxelTexId;

Sampler3D<uint> texVoxelTexId;


float3 VoxelTex_GetCenter(const in float3 cameraPos) {
    return VoxelTex_BufferCenter + fract(cameraPos);
}

float3 VoxelTex_GetBufferPosition(const in float3 localPos) {
    return localPos + VoxelTex_GetCenter(ap.camera.position);
}

bool VoxelTex_InBounds(const in int3 bufferPos) {
    return all(clamp(bufferPos, 0, VoxelTex_BufferSize-1) == bufferPos);
}

uint VoxelTex_pack(const in uint2 uv_min, const in uint2 uv_size, const in float3 normal) {
    uint2 scaled_min = uv_min / 8;
    uint size = uint(ceil(log2(uv_size.x))) - 3;

    uint priority = uint(dot(normal, float3(0.0, 2.0, 1.0) + 2.0));

    uint data = 0;
    data = bitfieldInsert(data, scaled_min.x,  0, 12);
    data = bitfieldInsert(data, scaled_min.y, 12, 12);
    data = bitfieldInsert(data,         size, 24,  5);
    data = bitfieldInsert(data,     priority, 29,  3);

    return data;
}

void VoxelTex_unpack(const in uint data, out uint2 uv_min, out uint2 uv_size) {
    uint2 scaled_min = uint2(
        bitfieldExtract(data,  0, 12),
        bitfieldExtract(data, 12, 12));
    
    uint size = bitfieldExtract(data, 24, 5);

    uv_min = scaled_min * 8;
    uv_size = uint2(exp2(size + 3));
}
