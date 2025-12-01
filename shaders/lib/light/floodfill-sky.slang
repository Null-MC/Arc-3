public module floodfill_sky;

import aperture;

extern static const int FloodFill_Sky_BufferSizeXZ;
extern static const int FloodFill_Sky_BufferSizeY;
// extern static const float FloodFill_FrustumOffsetF = 0.0;//VOXEL_FRUSTUM_OFFSET * 0.01;

static const uint3 FloodFill_Sky_BufferSize = uint3(FloodFill_Sky_BufferSizeXZ, FloodFill_Sky_BufferSizeY, FloodFill_Sky_BufferSizeXZ);
static const uint3 FloodFill_Sky_BufferCenter = FloodFill_Sky_BufferSize / 2;

[[vk::image_format("r16f")]]
RWTexture3D<half> imgFloodFill_Sky_write;

Sampler3D<half> texFloodFill_Sky_read;
Sampler3D<half> texFloodFill_Sky_write;


bool FloodFill_Sky_InBounds(const in int3 bufferPos) {
    return all(clamp(bufferPos, 0, FloodFill_Sky_BufferSize-1) == bufferPos);
}

bool FloodFill_Sky_InBounds(const in float3 bufferPos) {
    return all(clamp(bufferPos, 0.5, FloodFill_Sky_BufferSize-0.5) == bufferPos);
}

float3 FloodFill_Sky_GetBufferCenter(const in float3 viewPos) {
    return FloodFill_Sky_BufferCenter + fract(viewPos);
}

float3 FloodFill_Sky_GetBufferPosition(const in float3 localPos) {
    return localPos + FloodFill_Sky_GetBufferCenter(ap.camera.position);
}

float3 FloodFill_Sky_GetLocalPosition(const in float3 bufferPos) {
    return bufferPos - FloodFill_Sky_GetBufferCenter(ap.camera.position);
}

half floodfill_sky_sample(const in float3 bufferPos) {
    if (!FloodFill_Sky_InBounds(bufferPos)) return 0;

    float3 texcoord = bufferPos / FloodFill_Sky_BufferSize;
    return texFloodFill_Sky_write.Sample(texcoord) / 16.0;
}
